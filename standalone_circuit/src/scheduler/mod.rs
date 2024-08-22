use anyhow::{anyhow, bail, Result};
use async_recursion::async_recursion;
use axiom_eth::{halo2_proofs::poly::commitment::Prover, snark_verifier_sdk::Snark};
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
        self.post_proof_gen(request_id, circuit_id.as_str(),&result, );
        Ok(result.proof)
    }

    async fn get_circuit_id(&self, req: &RecursiveRequest) -> Result<String>;

    async fn generate_proof(&self, task: ProverTask) -> Result<ExecutionResult>;

    async fn post_proof_gen(
        &self,
        request_id: &str,
        circuit_id: &str,
        result: &ExecutionResult,
    ) -> Result<()>;

    async fn get_snarks_for_deps(
        &self,
        request_id: &str,
        req: &RecursiveRequest,
    ) -> Result<Vec<Snark>>;
}
