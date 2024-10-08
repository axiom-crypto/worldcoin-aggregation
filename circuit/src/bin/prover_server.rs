use clap::Parser;
use rocket::{get, http::Status, launch, post, routes, serde::json::Json, Build, Rocket, State};

use worldcoin_aggregation::{
    prover::{
        types::{ProverProof, ProverSnark, ProverTask, ProverTaskResponse, TaskInput},
        ProofRequest, ProverConfig, ProvingServerState,
    },
    scheduler::types::RequestRouter,
    types::*,
};

#[get("/build_info")]
async fn serve_build_info() -> String {
    "alive".to_string()
}

#[post("/reset")]
async fn reset(prover: &State<ProvingServerState>) -> Status {
    prover.reset().await;
    Status::Ok
}

#[post("/tasks", format = "json", data = "<task>")]
async fn serve(
    task: Json<ProverTask>,
    prover: &State<ProvingServerState>,
) -> Result<Json<ProverTaskResponse>> {
    let ProverTask { circuit_id, input } = task.into_inner();

    let TaskInput {
        is_evm_proof,
        request,
    } = input;

    match request {
        RequestRouter::Evm(request) => {
            if is_evm_proof {
                let evm_proof = prover.get_evm_proof(&circuit_id, request).await.unwrap();
                return Ok(Json(ProverTaskResponse {
                    payload: ProverProof::EvmProof(evm_proof),
                }));
            } else {
                return_snark(prover, circuit_id, request).await
            }
        }
        RequestRouter::Intermediate(request) => return_snark(prover, circuit_id, request).await,
        RequestRouter::Leaf(request) => return_snark(prover, circuit_id, request).await,
        RequestRouter::Root(request) => return_snark(prover, circuit_id, request).await,
    }
}

async fn return_snark<R: ProofRequest>(
    prover: &ProvingServerState,
    circuit_id: String,
    request: R,
) -> Result<Json<ProverTaskResponse>> {
    let snark = prover.get_snark(&circuit_id, request).await.unwrap();
    return Ok(Json(ProverTaskResponse {
        payload: ProverProof::Snark(ProverSnark {
            circuit_id: circuit_id,
            snark,
        }),
    }));
}

#[post("/internal/circuit-data", format = "json", data = "<task>")]
async fn load_circuit_data(
    task: Json<ProverTask>,
    prover: &State<ProvingServerState>,
) -> Result<()> {
    let ProverTask { circuit_id, input } = task.into_inner();

    let TaskInput {
        is_evm_proof,
        request,
    } = input;

    match request {
        RequestRouter::Leaf(request) => _ = prover.build_circuit(&circuit_id, request).await?,
        RequestRouter::Intermediate(request) => {
            _ = prover.build_circuit(&circuit_id, request).await?
        }
        RequestRouter::Root(request) => _ = prover.build_circuit(&circuit_id, request).await?,
        RequestRouter::Evm(request) => _ = prover.build_circuit(&circuit_id, request).await?,
    };

    Ok(())
}

#[derive(Parser, Clone, Debug)]
struct Cli {
    #[clap(flatten)]
    pub prover_config: ProverConfig,
}

#[launch]
fn rocket() -> Rocket<Build> {
    let cli = Cli::parse();
    let prover = ProvingServerState::new(cli.prover_config);

    rocket::build()
        .mount(
            "/",
            routes![serve, reset, serve_build_info, load_circuit_data],
        )
        .manage(prover)
}
