use std::{collections::HashMap, fs::File, path::PathBuf};

use anyhow::anyhow;
use clap::Parser;
use rocket::{get, http::Status, launch, post, routes, serde::json::Json, Build, Rocket, State};

use worldcoin_aggregation::{
    keygen::node_params::NodeParams,
    prover::{
        prover::ProverConfig,
        prover::ProvingServerState,
        types::{ProverProof, ProverSnark, ProverTask, ProverTaskResponse},
    },
    scheduler::types::RequestRouter,
    types::*,
};

#[get("/build_info")]
async fn serve_build_info() -> String {
    // TODO: this endpoint is just for heartbeat for now. Change it to return build info.
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
    let ProverTask {
        circuit_id,
        input: request,
    } = task.into_inner();

    match request {
        RequestRouter::Evm(request) => {
            let round = request.round;
            match round {
                1 => {
                    let evm_proof = prover.get_evm_proof(&circuit_id, request).await.unwrap();
                    return Ok(Json(ProverTaskResponse {
                        payload: ProverProof::EvmProof(evm_proof),
                    }));
                }
                0 => {
                    let snark = prover.get_snark(&circuit_id, request).await.unwrap();
                    return Ok(Json(ProverTaskResponse {
                        payload: ProverProof::Snark(ProverSnark { circuit_id, snark }),
                    }));
                }
                _ => {
                    return Err(anyhow!("incorrect rounds!")
                        .context(InvalidInputContext)
                        .into())
                }
            }
        }
        RequestRouter::Intermediate(request) => {
            let snark = prover.get_snark(&circuit_id, request).await.unwrap();
            return Ok(Json(ProverTaskResponse {
                payload: ProverProof::Snark(ProverSnark { circuit_id, snark }),
            }));
        }
        RequestRouter::Leaf(request) => {
            let snark = prover.get_snark(&circuit_id, request).await.unwrap();
            return Ok(Json(ProverTaskResponse {
                payload: ProverProof::Snark(ProverSnark { circuit_id, snark }),
            }));
        }
        RequestRouter::Root(request) => {
            let snark = prover.get_snark(&circuit_id, request).await.unwrap();
            return Ok(Json(ProverTaskResponse {
                payload: ProverProof::Snark(ProverSnark { circuit_id, snark }),
            }));
        }
    }
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
        .mount("/", routes![serve, reset, serve_build_info])
        .manage(prover)
}
