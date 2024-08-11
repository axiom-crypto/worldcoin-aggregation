use std::{collections::HashMap, hash::Hash, path::PathBuf, sync::Arc};

use anyhow::{anyhow, bail, Result};
use async_recursion::async_recursion;
use axiom_core::axiom_eth::snark_verifier_sdk::Snark;

use futures::future::join_all;
use rocket::tokio::{self, sync::RwLock};

use crate::{
    circuit_factory::{
        evm::*,
        v1::{
            intermediate::WorldcoinRequestIntermediate, leaf::WorldcoinRequestLeaf,
            root::WorldcoinRequestRoot,
        },
    },
    constants::VK,
    keygen::node_params::{NodeParams, NodeType},
    prover::types::{ProverProof, ProverTask},
    scheduler::{
        executor::{dispatcher::DispatcherExecutor, ProofExecutor},
        recursive_request::RecursiveRequest,
        types::*,
    },
    types::ClaimNative,
};

use super::task_tracker::SchedulerTaskTracker;

#[derive(Clone)]
pub struct AsyncScheduler {
    /// Mutex just to force sequential proving
    pub executor: Arc<dyn ProofExecutor>,
    pub circuit_id_repo: Arc<RwLock<HashMap<NodeParams, String>>>,
    pub cid_to_params: Arc<RwLock<HashMap<String, NodeParams>>>,
    pub task_tracker: Arc<SchedulerTaskTracker>,
    pub execution_summary_path: Arc<PathBuf>,
}

impl AsyncScheduler {
    pub fn new(
        circuit_id_repo: HashMap<NodeParams, String>,
        circuit_id_to_params: HashMap<String, NodeParams>,
        executor_url: String,
        task_tracker: SchedulerTaskTracker,
        execution_summary_path: PathBuf,
    ) -> Self {
        Self {
            circuit_id_repo: Arc::new(RwLock::new(circuit_id_repo)),
            cid_to_params: Arc::new(RwLock::new(circuit_id_to_params)),
            executor: Arc::new(DispatcherExecutor::new(&executor_url, 5000, 500, false).unwrap()),
            task_tracker: Arc::new(task_tracker),
            execution_summary_path: Arc::new(execution_summary_path),
        }
    }

    async fn get_request_leaf(
        &self,
        start: u32,
        end: u32,
        depth: usize,
        root: String,
        grant_id: String,
        claims: Vec<ClaimNative>,
    ) -> Result<WorldcoinRequestLeaf> {
        if end - start > (1 << depth) {
            bail!("start: {start}, end: {end}, cannot request more than 2^{depth} proofs");
        }

        Ok(WorldcoinRequestLeaf {
            start,
            end,
            depth,
            root,
            grant_id,
            claims,
            vk: VK.clone(),
        })
    }

    #[async_recursion]
    pub async fn handle_recursive_request(
        &self,
        request_id: &String,
        req: RecursiveRequest,
    ) -> Result<RequestRouter> {
        // Recursively generate the SNARKs for the dependencies of this task.
        let mut futures = vec![];
        for dep in req.dependencies() {
            let future = async move { self.recursive_gen_proof(request_id, dep).await };
            futures.push(future);
        }

        let results = join_all(futures).await;

        let mut snarks: Vec<Snark> = results
            .into_iter()
            .map(|result| {
                let snark = result.unwrap();
                match snark {
                    ProverProof::Snark(snark) => snark.snark.inner,
                    ProverProof::EvmProof(_) => unreachable!(),
                }
            })
            .collect();

        let RecursiveRequest {
            start,
            end,
            grant_id,
            root,
            claims,
            params,
        } = req;

        if params.depth == params.initial_depth {
            let leaf = self
                .get_request_leaf(start, end, params.depth, root, grant_id, claims)
                .await?;
            Ok(RequestRouter::Leaf(leaf))
        } else {
            assert!(!snarks.is_empty());
            Ok(match params.node_type {
                NodeType::Leaf => unreachable!(),
                NodeType::Intermediate => {
                    // TODO: the logic would be different for v2
                    if snarks.len() != 2 {
                        snarks.resize(2, snarks[0].clone()); // dummy snark
                    }
                    let req = WorldcoinRequestIntermediate {
                        start,
                        end,
                        snarks,
                        depth: params.depth,
                        initial_depth: params.initial_depth,
                    };
                    RequestRouter::Intermediate(req)
                }
                NodeType::Root => {
                    if snarks.len() != 2 {
                        snarks.resize(2, snarks[0].clone()); // dummy snark
                    }
                    let req = WorldcoinRequestRoot {
                        start,
                        end,
                        snarks,
                        depth: params.depth,
                        initial_depth: params.initial_depth,
                    };
                    RequestRouter::Root(req)
                }
                NodeType::Evm(round) => {
                    assert_eq!(snarks.len(), 1); // currently just passthrough
                    let snark = snarks.pop().unwrap();
                    let req = WorldcoinRequestEvm {
                        start,
                        end,
                        snark,
                        depth: params.depth,
                        initial_depth: params.initial_depth,
                        round,
                    };
                    RequestRouter::Evm(req)
                }
            })
        }
    }

    #[async_recursion]
    pub async fn recursive_gen_proof(
        &self,
        request_id: &String,
        req: RecursiveRequest,
    ) -> Result<ProverProof> {
        println!("Generating proof for {:?}", req);
        let req_router = self
            .handle_recursive_request(request_id, req.clone())
            .await?;
        let circuit_id = self
            .circuit_id_repo
            .read()
            .await
            .get(&req.params)
            .ok_or_else(|| anyhow!("Circuit ID for {:?} not found", req.params))?
            .to_owned();
        log::debug!("Router:{:?} CID-{circuit_id}", req.params);

        let task = ProverTask {
            circuit_id: circuit_id.clone(),
            input: req_router,
        };

        let result = self.executor.execute(task).await.unwrap();

        self.task_tracker
            .record_task(
                request_id.clone(),
                result.task_id,
                self.cid_to_params
                    .read()
                    .await
                    .get(&circuit_id)
                    .unwrap()
                    .clone(),
            )
            .unwrap();
        let proof = result.proof;
        Ok(proof)
    }
}
