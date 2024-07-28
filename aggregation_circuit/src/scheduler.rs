use std::{cmp::min, collections::HashMap, sync::Arc};

use anyhow::{anyhow, bail, Result};
use async_recursion::async_recursion;
use axiom_core::axiom_eth::snark_verifier_sdk::Snark;

use futures::future::join_all;
use rocket::tokio::{self, runtime::Runtime, sync::RwLock};

use crate::{
    circuit_factory::{
        evm::*,
        v1::{
            intermediate::WorldcoinRequestIntermediate, leaf::WorldcoinRequestLeaf,
            root::WorldcoinRequestRoot,
        },
    },
    keygen::node_params::{NodeParams, NodeType},
    prover::ProvingServerState,
    types::{ClaimNative, VkNative},
};

#[derive(Clone, Debug)]
pub struct RecursiveRequest {
    pub start: u32,
    pub end: u32,
    pub root: String,
    pub grant_id: String,
    pub claims: Vec<ClaimNative>,
    pub params: NodeParams,
}

impl RecursiveRequest {
    pub fn new(
        start: u32,
        end: u32,
        root: String,
        grant_id: String,
        claims: Vec<ClaimNative>,
        params: NodeParams,
    ) -> Result<Self> {
        if end <= start {
            bail!("end <= start")
        }
        if end - start > 1 << params.depth {
            bail!(
                "start: {start}, end: {end}, end - start > 2^{}",
                params.depth
            );
        }
        if params.depth < params.initial_depth {
            bail!("depth < initial_depth");
        }
        Ok(Self {
            start,
            end,
            root,
            grant_id,
            claims,
            params,
        })
    }

    pub fn num_proofs(&self) -> u32 {
        self.end - self.start
    }

    pub fn dependencies(&self) -> Vec<Self> {
        let RecursiveRequest {
            start,
            end,
            root,
            grant_id,
            claims,
            params,
        } = self.clone();
        assert!(end - start <= 1 << params.depth);
        if params.depth == params.initial_depth {
            vec![]
        } else {
            let child_params = params.child().unwrap();
            let child_depth = child_params.depth;
            // TODO: double check here, claims should be splited
            (start..end)
                .step_by(1 << child_depth)
                .map(|i| {
                    let start_idx = i;
                    let end_idx = min(end, i + (1 << child_depth));
                    Self {
                        start: start_idx,
                        end: end_idx,
                        root: root.clone(),
                        grant_id: grant_id.clone(),
                        claims: claims[(start_idx - start) as usize..(end_idx - start) as usize]
                            .to_vec(),
                        params: child_params,
                    }
                })
                .collect()
        }
    }
}

#[derive(Clone)]
pub struct Scheduler {
    /// Mutex just to force sequential proving
    pub state: Arc<ProvingServerState>,
    pub circuit_id_repo: Arc<RwLock<HashMap<NodeParams, String>>>,
    pub vk: VkNative,
}

impl Scheduler {
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
        grant_id: String,
        claims: Vec<ClaimNative>,
    ) -> Result<WorldcoinRequestLeaf> {
        if end - start > (1 << depth) {
            bail!("start: {start}, end: {end}, cannot request more than 2^{depth} blocks");
        }

        Ok(WorldcoinRequestLeaf {
            start,
            end,
            depth,
            root,
            grant_id,
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
                    // TODO: any case this would be happening
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

#[derive(Clone, Debug)]
pub enum RequestRouter {
    Leaf(WorldcoinRequestLeaf),
    Intermediate(WorldcoinRequestIntermediate),
    Root(WorldcoinRequestRoot),
    Evm(WorldcoinRequestEvm),
}
