use anyhow::{bail, Result};
use axiom_eth::snark_verifier_sdk::Snark;
use executor::ExecutionResult;
use recursive_request::RecursiveRequest;
use types::RequestRouter;

use crate::{
    circuit_factory::{
        evm::WorldcoinRequestEvm, intermediate::WorldcoinRequestIntermediate,
        leaf::WorldcoinRequestLeaf, root::WorldcoinRequestRoot,
    },
    constants::VK,
    keygen::node_params::NodeType,
    prover::types::{ProverProof, ProverTask, TaskInput},
    types::ClaimNative,
};
use async_trait::async_trait;

pub mod async_scheduler;
pub mod contract_client;
pub mod executor;
pub mod local_scheduler;
pub mod recursive_request;
pub mod task_tracker;
pub mod types;

#[async_trait]
pub trait Scheduler: Send + Sync + 'static {
    fn get_request_leaf(
        &self,
        start: u32,
        end: u32,
        depth: usize,
        root: String,
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
            claims,
            vk: VK.clone(),
        })
    }


    /// Recursively break down dependency tasks and schedule the execution. Return the prover task
    /// which needs to be executed for this request.
    async fn handle_recursive_request(
        &self,
        request_id: &str,
        req: RecursiveRequest,
    ) -> Result<RequestRouter> {
        let mut snarks = self.get_snarks_for_deps(request_id, &req).await?;

        let RecursiveRequest {
            start,
            end,
            root,
            claims,
            params,
        } = req;

        if params.depth == params.initial_depth {
            let leaf = self.get_request_leaf(start, end, params.depth, root, claims)?;
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

    /// Recursively break down proving jobs into smaller pieces and schedule the execution,
    /// generate proof for the given request, and execute post-processing.
    async fn recursive_gen_proof(
        &self,
        request_id: &str,
        req: RecursiveRequest,
        is_evm_proof: bool,
    ) -> Result<ProverProof> {
        let req_router = self
            .handle_recursive_request(request_id, req.clone())
            .await?;
        let circuit_id = self.get_circuit_id(&req).await?;

        log::debug!("Router:{:?} CID-{circuit_id}", req.params);

        let task = ProverTask {
            circuit_id: circuit_id.clone(),
            input: TaskInput {
                is_evm_proof,
                request: req_router,
            },
        };

        let result = self.generate_proof(task).await?;
        self.post_proof_gen_processing(request_id, circuit_id.as_str(), &result).await?;
        Ok(result.proof)
    }

    /// Find the circuit id which can handle this request
    async fn get_circuit_id(&self, req: &RecursiveRequest) -> Result<String>;

    // Generate proof for given task
    async fn generate_proof(&self, task: ProverTask) -> Result<ExecutionResult>;

    /// Processing that needs to be handled post proof generation, e.g. record the associated
    /// metadata for the request
    async fn post_proof_gen_processing(
        &self,
        request_id: &str,
        circuit_id: &str,
        result: &ExecutionResult,
    ) -> Result<()>;

    /// Get the snarks for the dependency tasks of the given request
    async fn get_snarks_for_deps(
        &self,
        request_id: &str,
        req: &RecursiveRequest,
    ) -> Result<Vec<Snark>>;
}
