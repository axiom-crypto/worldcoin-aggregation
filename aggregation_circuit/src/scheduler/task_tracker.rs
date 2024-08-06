use anyhow::bail;
use log::debug;
use parking_lot::Mutex;
use std::collections::HashMap;

use crate::{
    prover::types::ProverProof,
    scheduler::types::{current_timstamp_sec, SchedulerTaskStatus},
};

use super::types::SchedulerTaskStatusResponse;

#[derive(Debug)]
pub struct SchedulerTaskTracker {
    task_status_responses: Mutex<HashMap<String, SchedulerTaskStatusResponse>>,
}

impl SchedulerTaskTracker {
    pub fn new() -> Self {
        Self {
            task_status_responses: Default::default(),
        }
    }
    /// Create a new task or restart a failed task.
    pub fn create_task(&self, request_id: String) -> anyhow::Result<()> {
        log::debug!("create_task: {request_id} task_status_responses.lock");
        let mut task_status_responses = self.task_status_responses.lock();
        if let Some(task_status) = task_status_responses.get_mut(&request_id) {
            if task_status.status != SchedulerTaskStatus::Failed {
                bail!("Cannot create task {request_id} because it already exists")
            }
        }
        task_status_responses.insert(request_id, Default::default());
        drop(task_status_responses);
        Ok(())
    }
    /// Start a task. Wait if the concurrency has already reached the limit.
    pub async fn start_task(&self, request_id: &String) -> anyhow::Result<()> {
        log::debug!("start_task: {request_id} task_status_responses.lock");
        let mut task_status_responses = self.task_status_responses.lock();
        if let Some(task_status) = task_status_responses.get_mut(request_id) {
            if task_status.status != SchedulerTaskStatus::Pending {
                bail!(
                    "Cannot start task {request_id} because its status is {:?} instead of pending",
                    task_status.status
                )
            }
            task_status.status = SchedulerTaskStatus::Running;
            task_status.updated_at_sec = current_timstamp_sec();
        } else {
            bail!("Cannot start task {request_id} because it doesn't exists")
        }
        drop(task_status_responses);
        Ok(())
    }
    /// Finish a task with its proof. The correspponding execution permit must be destoried together.
    pub fn finish_task(
        &self,
        request_id: &String,
        query_proof_result: String,
    ) -> anyhow::Result<()> {
        // let QueryProofResult { final_proof, execution_summary } = query_proof_result;
        let proof = ProverProof::EvmProof(query_proof_result);
        debug!("Updating task {request_id} status to Done");
        debug!("finish_task:task_status_responses.lock");
        let mut task_status_responses = self.task_status_responses.lock();
        if let Some(task_status) = task_status_responses.get_mut(request_id) {
            if task_status.status != SchedulerTaskStatus::Running {
                bail!(
                    "Cannot finish task {request_id} because its status is {:?} instead of running",
                    task_status.status
                )
            }
            task_status.status = SchedulerTaskStatus::Done;
            task_status.snark = Some(proof);
            // task_status.execution_summary = Some(execution_summary);
            task_status.updated_at_sec = current_timstamp_sec();
        } else {
            bail!("Cannot finish task {request_id} because it doesn't exists")
        }
        drop(task_status_responses);

        debug!("Updated task {request_id} status to Done");
        Ok(())
    }
    /// Fail a task with its error message. The correspponding execution permit must be destoried together.
    pub fn fail_task(&self, request_id: &String, error: String) -> anyhow::Result<()> {
        debug!("Updating task {request_id} status to Failed");
        debug!("fail_task:task_status_responses.lock");
        let mut task_status_responses = self.task_status_responses.lock();
        if let Some(task_status) = task_status_responses.get_mut(request_id) {
            if task_status.status != SchedulerTaskStatus::Running {
                bail!(
                    "Cannot fail task {request_id} because its status is {:?} instead of running",
                    task_status.status
                )
            }
            task_status.status = SchedulerTaskStatus::Failed;
            task_status.error = Some(error);
            task_status.updated_at_sec = current_timstamp_sec();
        } else {
            bail!("Cannot fail task {request_id} because it doesn't exists")
        }
        drop(task_status_responses);

        debug!("Updated task {request_id} status to Failed");
        Ok(())
    }
    /// Get status of a task. Return None if the task doesn't exist.
    pub fn get_task_status(&self, request_id: &String) -> Option<SchedulerTaskStatusResponse> {
        debug!("get_task_status:task_status_responses.lock");
        let task_status_responses = self.task_status_responses.lock();
        task_status_responses.get(request_id).cloned()
    }
}
