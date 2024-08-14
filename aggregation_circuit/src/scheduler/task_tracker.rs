use parking_lot::Mutex;
use std::collections::HashMap;

use crate::keygen::node_params::NodeParams;

#[derive(Debug)]
pub struct SchedulerTaskTracker {
    // record all task information for the request
    // map request_id -> Vec<task>
    // task -> (task_id, node_params)
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
