use std::cmp::min;

use anyhow::{anyhow, bail, Result};

use crate::{keygen::node_params::NodeParams, types::ClaimNative};

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
