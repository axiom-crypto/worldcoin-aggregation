use std::{collections::HashMap, fs::File, path::PathBuf};

use anyhow::anyhow;
use clap::Parser;
use rocket::{launch, post, routes, serde::json::Json, Build, Rocket, State};
use tokio::task;
use worldcoin_aggregation::{
    constants::{EXTRA_ROUNDS, INITIAL_DEPTH},
    keygen::node_params::{NodeParams, NodeType},
    prover::prover::ProverConfig,
    scheduler::{
        async_scheduler::AsyncScheduler,
        local_scheduler::*,
        recursive_request::*,
        task_tracker::{self, SchedulerTaskTracker},
        types::{Request, SchedulerTaskRequest, SchedulerTaskResponse},
    },
    types::*,
};

use std::sync::Arc;

#[post("/tasks", format = "json", data = "<task>")]
async fn serve(
    task: Json<SchedulerTaskRequest>,
    scheduler: &State<Arc<AsyncScheduler>>,
) -> Result<Json<SchedulerTaskResponse>> {
    let SchedulerTaskRequest { request_id, input } = task.into_inner();
    let Request {
        num_proofs,
        max_proofs,
        root,
        grant_id,
        claims,
    } = input;

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

    task::spawn(async move {
        // Call the method on the cloned scheduler
        let proof = scheduler.recursive_gen_proof(req).await;
        log::info!("Successfully generated proof! {:?}", proof);
    });

    log::info!("Successfully created task!");

    return Ok(Json(SchedulerTaskResponse { request_id }));
}

#[derive(Parser, Clone, Debug)]
struct Cli {
    /// The path to the file with mappings between NodeParams and circuit IDs
    #[arg(long = "cids-path")]
    pub cids_path: PathBuf,
    #[arg(long = "executor-url")]
    pub executor_url: String,
}

#[launch]
fn rocket() -> Rocket<Build> {
    let cli = Cli::parse();
    let cids_file = File::open(&cli.cids_path)
        .unwrap_or_else(|_| panic!("Failed to open file {}", cli.cids_path.display()));
    let cids: Vec<(String, String)> =
        serde_json::from_reader(cids_file).expect("Failed to parse cids file");
    let cids_repo = HashMap::from_iter(cids.into_iter().map(|(k, cid)| {
        let params: NodeParams =
            serde_json::from_str(&k).unwrap_or_else(|e| panic!("Failed to parse {}. {:?}", k, e));
        (params, cid)
    }));

    let task_tracker = SchedulerTaskTracker::new();
    let scheduler: AsyncScheduler = AsyncScheduler::new(cids_repo, cli.executor_url, task_tracker);

    rocket::build()
        .mount("/", routes![serve])
        .manage(Arc::new(scheduler))
}
