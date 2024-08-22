use std::{collections::HashMap, sync::Arc};

use anyhow::{anyhow, Result};
use axiom_eth::snark_verifier_sdk::Snark;

use rocket::tokio::sync::RwLock;
use uuid::Uuid;

use crate::{
    keygen::node_params::NodeParams,
    prover::{
        types::{ProverProof, ProverSnark, ProverTask, TaskInput},
        ProvingServerState,
    },
    scheduler::types::RequestRouter,
    types::VkNative,
};

use async_trait::async_trait;

use super::{executor::ExecutionResult, recursive_request::RecursiveRequest, Scheduler};

#[derive(Clone)]
pub struct LocalScheduler {
    /// Mutex just to force sequential proving
    pub state: Arc<ProvingServerState>,
    pub circuit_id_repo: Arc<RwLock<HashMap<NodeParams, String>>>,
    pub vk: VkNative,
}

impl LocalScheduler {
    pub fn new(
        circuit_id_repo: HashMap<NodeParams, String>,
        state: ProvingServerState,
        vk: VkNative,
    ) -> Self {
        Self {
            circuit_id_repo: Arc::new(RwLock::new(circuit_id_repo)),
            state: Arc::new(state),
            vk,
        }
    }
}

#[async_trait]
impl Scheduler for LocalScheduler {
    async fn get_circuit_id(&self, req: &RecursiveRequest) -> Result<String> {
        let circuit_id = self
            .circuit_id_repo
            .read()
            .await
            .get(&req.params)
            .ok_or_else(|| anyhow!("Circuit ID for {:?} not found", req.params))?
            .to_owned();

        Ok(circuit_id)
    }

    async fn generate_proof(&self, task: ProverTask) -> Result<ExecutionResult> {
        let ProverTask { circuit_id, input } = task;
        let TaskInput {
            is_evm_proof,
            request,
        } = input;
        log::debug!("Router:{:?} CID", circuit_id);

        let task_id = Uuid::new_v4().to_string();

        if is_evm_proof {
            let proof = match request {
                RequestRouter::Leaf(_) => unreachable!(),
                RequestRouter::Intermediate(_) => unreachable!(),
                RequestRouter::Root(_) => unreachable!(),
                RequestRouter::Evm(req) => self.state.get_evm_proof(&circuit_id, req).await,
            }?;

            let execution_result = ExecutionResult {
                task_id,
                proof: ProverProof::EvmProof(proof),
            };

            Ok(execution_result)
        } else {
            let snark = match request {
                RequestRouter::Leaf(req) => self.state.get_snark(&circuit_id, req).await,
                RequestRouter::Intermediate(req) => self.state.get_snark(&circuit_id, req).await,
                RequestRouter::Root(req) => self.state.get_snark(&circuit_id, req).await,
                RequestRouter::Evm(req) => self.state.get_snark(&circuit_id, req).await,
            }?;

            let execution_result = ExecutionResult {
                task_id,
                proof: ProverProof::Snark(ProverSnark { snark, circuit_id }),
            };

            Ok(execution_result)
        }
    }

    async fn post_proof_gen(&self, _: &str, _: &str, _: &ExecutionResult) -> Result<()> {
        Ok(())
    }

    async fn get_snarks_for_deps(
        &self,
        request_id: &str,
        req: &RecursiveRequest,
    ) -> Result<Vec<Snark>> {
        let mut snarks: Vec<_> = vec![];

        for dep in req.dependencies() {
            let dep_snark = self.recursive_gen_proof(request_id, dep, false).await?;
            let dep_snark = match dep_snark {
                ProverProof::Snark(snark) => snark.snark.inner,
                ProverProof::EvmProof(_) => unreachable!(),
            };
            snarks.push(dep_snark);
        }

        Ok(snarks)
    }
}
