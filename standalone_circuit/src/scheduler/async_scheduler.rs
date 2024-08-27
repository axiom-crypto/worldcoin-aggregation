use std::{collections::HashMap, path::PathBuf, sync::Arc};

use anyhow::{anyhow, Result};
use axiom_eth::snark_verifier_sdk::Snark;

use futures::future::join_all;
use rocket::tokio::sync::RwLock;

use crate::{
    keygen::node_params::NodeParams,
    prover::types::{ProverProof, ProverTask},
    scheduler::{
        executor::{dispatcher::DispatcherExecutor, ProofExecutor},
        recursive_request::RecursiveRequest,
    },
};

use super::{
    contract_client::ContractClient, executor::ExecutionResult, task_tracker::SchedulerTaskTracker,
    Scheduler,
};

use async_trait::async_trait;

#[derive(Clone)]
pub struct AsyncScheduler {
    // executor that can generate proof for a given task
    pub executor: Arc<dyn ProofExecutor>,
    // circuit_id -> intent params
    pub circuit_id_repo: Arc<RwLock<HashMap<NodeParams, String>>>,
    // intent params -> circuit_id
    pub cid_to_params: Arc<RwLock<HashMap<String, NodeParams>>>,
    // tracker for existing tasks
    pub task_tracker: Arc<SchedulerTaskTracker>,
    // the path for storing execution_summary
    pub execution_summary_path: Arc<PathBuf>,
    // the client to interact with the smart contract
    pub contract_client: Arc<ContractClient>,
    // the node params of the final aggregation circuit
    pub final_circuit_params: Arc<NodeParams>,
}

#[async_trait]
impl Scheduler for AsyncScheduler {
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

    async fn generate_proof(&self, task: ProverTask) -> Result<super::executor::ExecutionResult> {
        self.executor.execute(task).await
    }

    async fn post_proof_gen_processing(
        &self,
        request_id: &str,
        circuit_id: &str,

        result: &ExecutionResult,
    ) -> Result<()> {
        let cid_to_params = self.cid_to_params.read().await;
        let node_params = cid_to_params.get(circuit_id).unwrap();

        self.task_tracker
            .record_task(request_id, &result.task_id, node_params)
            .await
    }

    async fn get_snarks_for_deps(
        &self,
        request_id: &str,
        req: &RecursiveRequest,
    ) -> Result<Vec<Snark>> {
        let mut futures = vec![];
        for dep in req.dependencies() {
            let future = async move { self.recursive_gen_proof(request_id, dep, false).await };
            futures.push(future);
        }

        let results = join_all(futures).await;

        let snarks: Vec<Snark> = results
            .into_iter()
            .map(|result| {
                result.map(|snark| match snark {
                    ProverProof::Snark(snark) => snark.snark.inner,
                    ProverProof::EvmProof(_) => unreachable!(),
                })
            })
            .collect::<Result<Vec<Snark>, _>>()?;

        Ok(snarks)
    }
}

impl AsyncScheduler {
    pub fn new(
        circuit_id_repo: HashMap<NodeParams, String>,
        circuit_id_to_params: HashMap<String, NodeParams>,
        executor_url: String,
        task_tracker: SchedulerTaskTracker,
        execution_summary_path: PathBuf,
        contract_client: ContractClient,
        final_circuit_param: NodeParams
    ) -> Self {
        // query task status from dispatcher every 5000 ms
        const DISPATCHER_POLL_INTERVAL: u64 = 5000;
        // threshold for concurrent tasks
        const DISPATCHER_CONCURRENCY: usize = 100;
        // whether to re-prove in case the input for the circuit already has proof from previous runs
        const FORCE_PROVE: bool = false;

        Self {
            circuit_id_repo: Arc::new(RwLock::new(circuit_id_repo)),
            cid_to_params: Arc::new(RwLock::new(circuit_id_to_params)),
            executor: Arc::new(
                DispatcherExecutor::new(
                    &executor_url,
                    DISPATCHER_POLL_INTERVAL,
                    DISPATCHER_CONCURRENCY,
                    FORCE_PROVE,
                )
                .unwrap(),
            ),
            task_tracker: Arc::new(task_tracker),
            execution_summary_path: Arc::new(execution_summary_path),
            contract_client: Arc::new(contract_client),
            final_circuit_params: Arc::new(final_circuit_param)
        }
    }
}
