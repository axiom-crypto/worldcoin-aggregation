use std::{collections::HashMap, fmt::format, fs::File, io::Write, path::PathBuf};

use anyhow::anyhow;
use axiom_components::groth16::verifier::types::Proof;
use clap::Parser;
use ethers::types::transaction::request;
use rocket::{launch, post, routes, serde::json::Json, Build, Rocket, State};
use tokio::task;
use uuid::Uuid;
use worldcoin_aggregation::{
    constants::{EXTRA_ROUNDS, INITIAL_DEPTH},
    keygen::node_params::{NodeParams, NodeType},
    prover::{prover::ProverConfig, types::ProverProof},
    scheduler::{
        async_scheduler::AsyncScheduler,
        local_scheduler::*,
        recursive_request::*,
        task_tracker::{self, SchedulerTaskTracker},
        types::{SchedulerTaskRequest, SchedulerTaskResponse},
    },
    types::*,
};

use std::sync::Arc;

#[post("/tasks", format = "json", data = "<task>")]
async fn serve(
    task: Json<SchedulerTaskRequest>,
    scheduler: &State<Arc<AsyncScheduler>>,
) -> Result<Json<SchedulerTaskResponse>> {

    let SchedulerTaskRequest {
        num_proofs,
        max_proofs,
        root,
        grant_id,
        claims,
        initial_depth
    } = task.into_inner();

    let initial_depth = initial_depth.unwrap_or(INITIAL_DEPTH);

    if num_proofs > max_proofs {
        return Err(anyhow!("Too many proofs!")
            .context(InvalidInputContext)
            .into());
    }

    if !max_proofs.is_power_of_two() {
        return Err(anyhow!("max proofs must be power of two")
            .context(InvalidInputContext)
            .into());
    }

    if num_proofs != claims.len() {
        return Err(anyhow!("max proofs and claims must have the same length")
            .context(InvalidInputContext)
            .into());
    }

    let depth = max_proofs.trailing_zeros();

    let params = NodeParams::new(NodeType::Evm(EXTRA_ROUNDS), depth as usize, INITIAL_DEPTH);

    let req = RecursiveRequest {
        start: 0,
        end: num_proofs as u32,
        root,
        grant_id,
        claims,
        params,
    };

    //let scheduler = AsyncScheduler::clone(scheduler);
    // Actually run the thing
    log::info!("Running task: {req:?}");

    //task_tracker.create_task(request_id.clone())?;
    let scheduler = Arc::clone(&scheduler.inner());

    let request_id = Uuid::new_v4().to_string();
    let request_id_clone = request_id.clone();

    task::spawn(async move {
        // Call the method on the cloned scheduler
        let proof = scheduler
            .recursive_gen_proof(&request_id, req)
            .await
            .unwrap();
        match proof {
            ProverProof::EvmProof(final_proof) => {
                log::info!("Successfully generated proof! {:?}", final_proof);

                let request_id_to_tasks = scheduler.task_tracker.request_id_to_tasks.lock();
                let tasks = request_id_to_tasks.get(&request_id).unwrap();
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
                // fulfill final_proof
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

    let mut cids_repo: HashMap<NodeParams, String> = HashMap::new();
    let mut cid_to_params: HashMap<String, NodeParams> = HashMap::new();
    for (params, circuit_id) in cids {
        let params: NodeParams = serde_json::from_str(&params)
            .unwrap_or_else(|e| panic!("Failed to parse {}. {:?}", params, e));
        cids_repo.insert(params.clone(), circuit_id.clone());
        cid_to_params.insert(circuit_id, params);
    }

    let task_tracker = SchedulerTaskTracker::new();
    let scheduler: AsyncScheduler = AsyncScheduler::new(
        cids_repo,
        cid_to_params,
        cli.executor_url,
        task_tracker,
        cli.execution_summary_path,
    );

    rocket::build()
        .mount("/", routes![serve])
        .manage(Arc::new(scheduler))
}
