use std::{collections::HashMap, env, fs::File, io::Write, path::PathBuf};

use anyhow::anyhow;
use clap::Parser;
use rocket::{get, launch, post, routes, serde::json::Json, Build, Rocket, State};
use tokio::task;
use uuid::Uuid;
use worldcoin_aggregation::{
    constants::{EXTRA_ROUNDS, INITIAL_DEPTH},
    keygen::node_params::{NodeParams, NodeType},
    prover::types::ProverProof,
    scheduler::{
        async_scheduler::AsyncScheduler,
        contract_client::{ContractClient, V1ClaimParams},
        recursive_request::*,
        task_tracker::SchedulerTaskTracker,
        types::{SchedulerTaskRequest, SchedulerTaskResponse},
    },
    types::*,
};

use std::sync::Arc;
use worldcoin_aggregation::scheduler::Scheduler;

#[get("/")]
fn index() -> &'static str {
    "I'm alive!"
}

#[post("/tasks", format = "json", data = "<task>")]
async fn serve(
    task: Json<SchedulerTaskRequest>,
    scheduler: &State<Arc<AsyncScheduler>>,
) -> Result<Json<SchedulerTaskResponse>> {
    let SchedulerTaskRequest {
        root,
        claims,
    } = task.into_inner();


    let num_proofs = claims.len();

    let final_circuit_params = (*scheduler.final_circuit_params).clone();
    let NodeParams{ node_type: _, depth, initial_depth} = final_circuit_params;

    let max_proofs = 1 << depth;

    if num_proofs == 0 {
         return Err(anyhow!("Zero proofs!")
            .context(InvalidInputContext)
            .into());
    }

    if num_proofs > max_proofs {
        return Err(anyhow!("Too many proofs!")
            .context(InvalidInputContext)
            .into());
    }


    let req = RecursiveRequest {
        start: 0,
        end: num_proofs as u32,
        root,
        claims,
        params: final_circuit_params,
    };

    // Actually run the thing
    log::info!("Running task: {req:?}");

    let scheduler = Arc::clone(&scheduler.inner());

    let request_id = Uuid::new_v4().to_string();
    let request_id_clone = request_id.clone();

    let contract_client = Arc::clone(&scheduler.contract_client);

    task::spawn(async move {
        let proof = scheduler
            .recursive_gen_proof(&request_id, req.clone(), true)
            .await
            .unwrap();

        match proof {
            ProverProof::EvmProof(final_proof) => {
                log::info!("Successfully generated proof! {:?}", final_proof);

                let request_id_to_tasks = scheduler.task_tracker.request_id_to_tasks.lock().await;

                let tasks: &Vec<(String, NodeParams)> =
                    request_id_to_tasks.get(&request_id).unwrap();
                // dump execution summary
                let json_string =
                    serde_json::to_string_pretty(tasks).expect("Failed to serialize data to JSON");
                let mut file = File::create(
                    scheduler
                        .execution_summary_path
                        .join(format!("{}.json", request_id)),
                )
                .unwrap();
                file.write_all(json_string.as_bytes()).unwrap();

                let retry_send_threshold = 5;

                // the vk_hash for the corresponding vk.json
                const VK_HASH: &str =
                    "0x46e72119ce99272ddff09e0780b472fdc612ca799c245eea223b27e57a5f9cec";

                #[cfg(feature = "v1")]
                let params = V1ClaimParams::new(VK_HASH, &req.root, &req.claims, final_proof);
                #[cfg(feature = "v2")]
                let params = final_proof;

                for _i in 0..retry_send_threshold {
                    let ret = contract_client.fulfill(params.clone()).await;
                    match ret {
                        Ok(tx_hash) => {
                            println!("fulfilled query {}, tx_hash {}", request_id, tx_hash);
                            return;
                        }
                        Err(_) => {
                            println!("Failed to fulfill request {}, retrying", request_id);
                            tokio::time::sleep(tokio::time::Duration::from_secs(3)).await;
                        }
                    }
                }
                println!(
                    "Failed to fulfill request {} after {} retries",
                    request_id, retry_send_threshold
                );
            }
            _ => unreachable!(),
        }
    });

    log::info!("Successfully created task!");

    return Ok(Json(SchedulerTaskResponse {
        request_id: request_id_clone,
    }));
}

#[derive(Parser, Clone, Debug)]
struct Cli {
    /// The path to the file with mappings between NodeParams and circuit IDs
    #[arg(long = "cids-path")]
    pub cids_path: PathBuf,
    #[arg(long = "executor-url")]
    pub executor_url: String,
    #[arg(long = "execution-summary", default_value = "./execution_summary")]
    pub execution_summary_path: PathBuf,
}

#[launch]
fn rocket() -> Rocket<Build> {
    let cli = Cli::parse();
    let cids_file = File::open(&cli.cids_path)
        .unwrap_or_else(|_| panic!("Failed to open file {}", cli.cids_path.display()));
    let cids: Vec<(String, String)> =
        serde_json::from_reader(cids_file).expect("Failed to parse cids file");

    assert!(cids.len() > 0);
    let final_circuit_params = cids.last().unwrap().clone().0;
    let final_circuit_params: NodeParams = serde_json::from_str(&final_circuit_params)
            .unwrap_or_else(|e| panic!("Failed to parse {}. {:?}", final_circuit_params, e));

    let mut cids_repo: HashMap<NodeParams, String> = HashMap::new();
    let mut cid_to_params: HashMap<String, NodeParams> = HashMap::new();
    for (params, circuit_id) in cids {
        let params: NodeParams = serde_json::from_str(&params)
            .unwrap_or_else(|e| panic!("Failed to parse {}. {:?}", params, e));
        cids_repo.insert(params.clone(), circuit_id.clone());
        cid_to_params.insert(circuit_id, params);
    }

    let task_tracker = SchedulerTaskTracker::new();

    const CHAIN_ID: u64 = 11155111;
    let contract_address = env::var("CONTRACT_ADDRESS").expect("CONTRACT_ADDRESS must be set");
    let keystore_path = env::var("KEYSTORE_PATH").expect("KEYSTORE_PATH must be set");
    let keystore_password = env::var("KEYSTORE_PASSWORD").expect("KEYSTORE_PASSWORD must be set");
    let provider_uri = env::var("PROVIDER_URI").expect("PROVIDER_URL must be set");

    let contract_client = ContractClient::new(
        &keystore_path,
        &keystore_password,
        &provider_uri,
        &contract_address,
        CHAIN_ID,
    )
    .unwrap();

    let scheduler: AsyncScheduler = AsyncScheduler::new(
        cids_repo,
        cid_to_params,
        cli.executor_url,
        task_tracker,
        cli.execution_summary_path,
        contract_client,
        final_circuit_params
    );

    rocket::build()
        .mount("/", routes![serve, index])
        .manage(Arc::new(scheduler))
}
