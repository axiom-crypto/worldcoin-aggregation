use async_trait::async_trait;

use serde::{Deserialize, Serialize};

use crate::prover::types::{ProverProof, ProverTask};

use super::types::current_timstamp_sec;

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
    pub summary: ExecutionSummary,
    pub proof: ProverProof,
}

#[async_trait]
pub trait ProofExecutor: Send + Sync + 'static {
    async fn execute(&self, proof: ProverTask) -> anyhow::Result<ExecutionResult> {
        let execution_started_at_sec = current_timstamp_sec();
        let circuit_id = proof.circuit_id.clone();

        let (task_id, proof) = self.execute_impl(proof).await?;

        let execution_finished_at_sec = current_timstamp_sec();
        let execution_sumamry = ExecutionSummary {
            task_id,
            circuit_id,
            execution_started_at_sec,
            execution_finished_at_sec,
        };
        Ok(ExecutionResult {
            summary: execution_sumamry,
            proof,
        })
    }
    async fn execute_impl(&self, proof: ProverTask) -> anyhow::Result<(TaskId, ProverProof)>;
}
