use anyhow::bail;
use parking_lot::Mutex;
use std::collections::HashMap;

use crate::{
    keygen::node_params::NodeParams,
    prover::types::ProverProof,
    scheduler::types::{current_timstamp_sec, SchedulerTaskStatus},
};

#[derive(Debug)]
pub struct SchedulerTaskTracker {
    // record all task ids for the request
    pub request_id_to_tasks: Mutex<HashMap<String, Vec<(String, NodeParams)>>>,
}

impl SchedulerTaskTracker {
    pub fn new() -> Self {
        Self {
            request_id_to_tasks: Default::default(),
        }
    }

    pub fn record_task(
        &self,
        request_id: String,
        task_id: String,
        params: NodeParams,
    ) -> anyhow::Result<()> {
        let mut request_id_to_task_ids = self.request_id_to_tasks.lock();
        request_id_to_task_ids
            .entry(request_id)
            .or_insert_with(Vec::new)
            .push((task_id, params));
        Ok(())
    }
}
