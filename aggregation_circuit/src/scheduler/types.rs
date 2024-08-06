use std::time::{SystemTime, UNIX_EPOCH};

use serde::{Deserialize, Serialize};

use crate::{
    circuit_factory::{
        evm::WorldcoinRequestEvm,
        v1::{
            intermediate::WorldcoinRequestIntermediate, leaf::WorldcoinRequestLeaf,
            root::WorldcoinRequestRoot,
        },
    },
    prover::types::ProverProof,
    types::ClaimNative,
};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub enum RequestRouter {
    Leaf(WorldcoinRequestLeaf),
    Intermediate(WorldcoinRequestIntermediate),
    Root(WorldcoinRequestRoot),
    Evm(WorldcoinRequestEvm),
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Request {
    pub root: String,
    pub grant_id: String,
    // the claims vector has [start, end) claims
    pub claims: Vec<ClaimNative>,
    pub num_proofs: usize,
    pub max_proofs: usize,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct SchedulerTaskRequest {
    pub request_id: String,
    pub input: Request,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct SchedulerTaskResponse {
    pub request_id: String,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct SchedulerTaskStatusResponse {
    pub status: SchedulerTaskStatus,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub snark: Option<ProverProof>,
    //#[serde(skip_serializing_if = "Option::is_none")]
    //pub execution_summary: Option<QueryProofExecutionSummary>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
    pub created_at_sec: u64,
    pub updated_at_sec: u64,
}

impl Default for SchedulerTaskStatusResponse {
    fn default() -> Self {
        let now = current_timstamp_sec();
        Self {
            status: SchedulerTaskStatus::Pending,
            snark: None,
            // execution_summary: None,
            error: None,
            created_at_sec: now,
            updated_at_sec: now,
        }
    }
}

pub fn current_timstamp_sec() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs()
}

#[derive(Serialize, Deserialize, Copy, Clone, Debug, PartialEq, Eq)]
#[serde(rename_all = "UPPERCASE")]
pub enum SchedulerTaskStatus {
    Pending,
    Running,
    Done,
    Failed,
}
