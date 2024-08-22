use std::{collections::HashMap, fs::File, path::PathBuf};

use anyhow::anyhow;
use clap::Parser;
use rocket::{http::Status, launch, post, routes, serde::json::Json, Build, Rocket, State};
use serde::{Deserialize, Serialize};
use std::fs;
use uuid::Uuid;
use worldcoin_aggregation::{
    constants::{EXTRA_ROUNDS, INITIAL_DEPTH},
    keygen::node_params::{NodeParams, NodeType},
    prover::{types::ProverProof, ProverConfig, ProvingServerState},
    scheduler::{local_scheduler::*, recursive_request::*, Scheduler},
    types::*,
};

#[derive(Serialize, Deserialize)]
struct Request {
    // start index of the claim, inclusive
    start: u32,
    // end index of the claim, exclusive
    end: u32,
    root: String,
    grant_id: String,
    // the claims vector has [start, end) claims
    claims: Vec<ClaimNative>,

    #[serde(skip_serializing_if = "Option::is_none")]
    depth: Option<usize>,
    #[serde(skip_serializing_if = "Option::is_none")]
    is_final: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    for_evm: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    rounds: Option<usize>,
}

#[post("/reset")]
async fn reset(scheduler: &State<LocalScheduler>) -> Status {
    scheduler.state.reset().await;
    Status::Ok
}

/// synchronously run the task and its dependencies, it will store generated snarks in local fs
#[post("/prove", format = "json", data = "<task>")]
async fn serve(task: Json<Request>, scheduler: &State<LocalScheduler>) -> Result<String> {
    let Request {
        start,
        end,
        root,
        grant_id,
        claims,
        depth,
        is_final,
        for_evm,
        rounds,
    } = task.into_inner();

    let depth = depth.unwrap_or(INITIAL_DEPTH);
    if end - start > 1 << depth {
        return Err(anyhow!("Too many proofs!")
            .context(InvalidInputContext)
            .into());
    }
    let is_final = is_final.unwrap_or(true);
    let for_evm = for_evm.unwrap_or(true);
    if for_evm && !is_final {
        return Err(anyhow!("EVM proofs must be final!")
            .context(InvalidInputContext)
            .into());
    }
    let node_type = if is_final {
        if for_evm {
            NodeType::Evm(rounds.unwrap_or(EXTRA_ROUNDS))
        } else {
            NodeType::Root
        }
    } else if depth == INITIAL_DEPTH {
        NodeType::Leaf
    } else {
        NodeType::Intermediate
    };
    let params = NodeParams::new(node_type, depth, INITIAL_DEPTH);
    let req = RecursiveRequest {
        start,
        end,
        root,
        claims,
        params,
    };

    let scheduler = LocalScheduler::clone(scheduler);
    // Actually run the thing
    log::info!("Running task: {req:?}");
    let request_id = Uuid::new_v4();

    let evm_proof = if for_evm {
        let prover_proof  = scheduler
            .recursive_gen_proof(request_id.to_string().as_str(), req, true)
            .await?;
        match prover_proof {
            ProverProof::EvmProof(proof) => proof,
            ProverProof::Snark(_) => unreachable!()
        }
    } else {
        scheduler
            .recursive_gen_proof(request_id.to_string().as_str(), req, false)
            .await?;
        "".to_string()
    };
    log::info!("Task complete!");

    Ok(evm_proof)
}

#[derive(Parser, Clone, Debug)]
struct Cli {
    #[clap(flatten)]
    pub prover_config: ProverConfig,
    /// The path to the file with mappings between NodeParams and circuit IDs
    #[arg(long = "cids-path")]
    pub cids_path: PathBuf,
}

#[launch]
fn rocket() -> Rocket<Build> {
    let cli = Cli::parse();
    let cids_file = File::open(&cli.cids_path)
        .unwrap_or_else(|_| panic!("Failed to open file {}", cli.cids_path.display()));
    let cids: Vec<(String, String)> =
        serde_json::from_reader(cids_file).expect("Failed to parse cids file");
    let cids_repo: HashMap<NodeParams, String> =
        HashMap::from_iter(cids.into_iter().map(|(k, cid)| {
            let params: NodeParams = serde_json::from_str(&k)
                .unwrap_or_else(|e| panic!("Failed to parse {}. {:?}", k, e));
            (params, cid)
        }));

    let state = ProvingServerState::new(cli.prover_config);

    let data = fs::read_to_string("./data/vk.json").unwrap();
    let vk: VkNative = serde_json::from_str(&data).unwrap();

    let scheduler: LocalScheduler = LocalScheduler::new(cids_repo, state, vk);
    rocket::build()
        .mount("/", routes![serve, reset])
        .manage(scheduler)
}
