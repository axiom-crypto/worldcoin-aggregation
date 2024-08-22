use std::collections::HashMap;
use tokio::sync::Mutex;

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

    pub async fn record_task(
        &self,
        request_id: &str,
        task_id: &str,
        params: &NodeParams,
    ) -> anyhow::Result<()> {
        let request_id_to_task_ids = self.request_id_to_tasks.lock();
        request_id_to_task_ids
            .await
            .entry(request_id.to_string())
            .or_insert_with(Vec::new)
            .push((task_id.clone().to_string(), params.clone()));
        Ok(())
    }
}
