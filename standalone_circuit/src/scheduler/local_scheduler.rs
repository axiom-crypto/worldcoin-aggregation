use std::{collections::HashMap, sync::Arc};

use anyhow::{anyhow, bail, Result};
use async_recursion::async_recursion;
use axiom_eth::snark_verifier_sdk::Snark;

use rocket::tokio::sync::RwLock;

use crate::{
    circuit_factory::{
        evm::*,
        {
            intermediate::WorldcoinRequestIntermediate, leaf::WorldcoinRequestLeaf,
            root::WorldcoinRequestRoot,
        },
    },
    keygen::node_params::{NodeParams, NodeType},
    prover::ProvingServerState,
    scheduler::types::RequestRouter,
    types::{ClaimNative, VkNative},
};

use super::recursive_request::RecursiveRequest;

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

    async fn get_request_leaf(
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
            vk: self.vk.clone(),
        })
    }

    // Recursion with futures is complicated, so we use a synchronous version.
    #[async_recursion]
    pub async fn handle_recursive_request(&self, req: RecursiveRequest) -> Result<RequestRouter> {
        // Recursively generate the SNARKs for the dependencies of this task.
        let mut snarks = vec![];
        for dep in req.dependencies() {
            let dep_snark = self.recursive_get_snark(dep).await?;
            snarks.push(dep_snark);
        }
        let RecursiveRequest {
            start,
            end,
            root,
            claims,
            params,
        } = req;
        if params.depth == params.initial_depth {
            let leaf = self
                .get_request_leaf(start, end, params.depth, root, claims)
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
    pub async fn recursive_get_snark(&self, req: RecursiveRequest) -> Result<Snark> {
        let req_router = self.handle_recursive_request(req.clone()).await?;
        let circuit_id = self
            .circuit_id_repo
            .read()
            .await
            .get(&req.params)
            .ok_or_else(|| anyhow!("Circuit ID for {:?} not found", req.params))?
            .to_owned();
        log::debug!("Router:{:?} CID-{circuit_id}", req.params);
        let snark = match req_router {
            RequestRouter::Leaf(req) => self.state.get_snark(&circuit_id, req).await,
            RequestRouter::Intermediate(req) => self.state.get_snark(&circuit_id, req).await,
            RequestRouter::Root(req) => self.state.get_snark(&circuit_id, req).await,
            RequestRouter::Evm(req) => self.state.get_snark(&circuit_id, req).await,
        }?;

        Ok(snark.inner)
    }

    #[async_recursion]
    pub async fn recursive_get_evm_proof(&self, req: RecursiveRequest) -> Result<String> {
        let req_router = self.handle_recursive_request(req.clone()).await?;
        let circuit_id = self
            .circuit_id_repo
            .read()
            .await
            .get(&req.params)
            .ok_or_else(|| anyhow!("Circuit ID for {:?} not found", req.params))?
            .to_owned();
        log::debug!("Router:{:?} CID-{circuit_id}", req.params);
        match req_router {
            RequestRouter::Leaf(req) => self.state.get_evm_proof(&circuit_id, req).await,
            RequestRouter::Intermediate(req) => self.state.get_evm_proof(&circuit_id, req).await,
            RequestRouter::Root(req) => self.state.get_evm_proof(&circuit_id, req).await,
            RequestRouter::Evm(req) => self.state.get_evm_proof(&circuit_id, req).await,
        }
    }
}
