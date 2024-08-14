use async_trait::async_trait;

use serde::{Deserialize, Serialize};

use crate::prover::types::{ProverProof, ProverTask};

pub mod dispatcher;

pub type TaskId = String;

#[derive(Clone, Serialize, Deserialize, Debug)]
pub struct ExecutionSummary {
    task_id: TaskId,
    circuit_id: String,
    execution_started_at_sec: u64,
    execution_finished_at_sec: u64,
}

#[derive(Clone, Serialize, Deserialize, Debug)]
pub struct ExecutionResult {
    pub task_id: String,
    pub proof: ProverProof,
}

#[async_trait]
pub trait ProofExecutor: Send + Sync + 'static {
    async fn execute(&self, proof: ProverTask) -> anyhow::Result<ExecutionResult> {
        let (task_id, proof) = self.execute_impl(proof).await?;

        Ok(ExecutionResult { task_id, proof })
    }
    async fn execute_impl(&self, proof: ProverTask) -> anyhow::Result<(TaskId, ProverProof)>;
}
