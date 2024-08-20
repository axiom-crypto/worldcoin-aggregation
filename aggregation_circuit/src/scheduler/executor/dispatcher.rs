use anyhow::{bail, Context};
use async_trait::async_trait;
use log::debug;
use reqwest_middleware::{ClientBuilder, ClientWithMiddleware};
use reqwest_retry::{policies::ExponentialBackoff, RetryTransientMiddleware};
use serde::{Deserialize, Serialize};
use tokio::{sync::Semaphore, time::Duration};

use crate::prover::types::{ProverProof, ProverTask, ProverTaskResponse, TaskInput};

use super::ProofExecutor;

#[derive(Serialize, Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
struct TasksRequest {
    pub circuit_id: String,
    pub input: TaskInput,
    pub force_prove: bool,
}

type TasksResponse = TaskId;
type TaskId = String;

#[derive(Serialize, Deserialize, PartialEq, Eq, Debug)]
#[serde(rename_all = "UPPERCASE")]
enum TaskStatus {
    PENDING,
    PREPARING,
    PROVING,
    DONE,
    FAILED,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct TaskStatusResponse {
    pub status: TaskStatus,
}

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct ProverProofResponse {
    pub snark: ProverTaskResponse,
}

pub struct DispatcherExecutor {
    pub(crate) url: reqwest::Url,
    pub(crate) poll_interval: Duration,
    pub(crate) proof_concurrency_semaphore: Option<Semaphore>,
    pub(crate) force_prove: bool,
}

#[async_trait]
impl ProofExecutor for DispatcherExecutor {
    async fn execute_impl(&self, proof: ProverTask) -> anyhow::Result<(TaskId, ProverProof)> {
        let permit = if let Some(sem) = self.proof_concurrency_semaphore.as_ref() {
            Some(sem.acquire().await?)
        } else {
            None
        };
        let task_id = self.create_task(proof).await?;

        self.wait_task_done(&task_id).await?;
        drop(permit);
        let prover_proof = self.get_prover_proof(&task_id).await?;
        Ok((task_id, prover_proof))
    }
}

impl DispatcherExecutor {
    pub fn new(
        url: &String,
        poll_interval_ms: u64,
        proof_concurrency: usize,
        force_prove: bool,
    ) -> anyhow::Result<Self> {
        let proof_concurrency_semaphore = if proof_concurrency == 0 {
            None
        } else {
            Some(Semaphore::new(proof_concurrency))
        };
        Ok(Self {
            url: reqwest::Url::parse(url)?,
            poll_interval: Duration::from_millis(poll_interval_ms),
            proof_concurrency_semaphore,
            force_prove,
        })
    }
    async fn create_task(&self, proof: ProverTask) -> anyhow::Result<TaskId> {
        let circuit_id = proof.circuit_id.clone();
        debug!("Creating dispatcher task for circuit id {}", circuit_id);
        let client = self.build_client();
        let task_url = self.url.join("tasks")?;
        let body = TasksRequest {
            circuit_id: proof.circuit_id,
            input: proof.input,
            force_prove: self.force_prove,
        };

        let resp = client
            .post(task_url.clone())
            .json(&body)
            .send()
            .await
            .with_context(|| format!("Failed when requesting {task_url}"))?;
        let task_id: TasksResponse = resp
            .json()
            .await
            .with_context(|| format!("Failed to parse response of /tasks"))?;

        debug!(
            "Dispatcher task for circuit id {} is created, task id {}",
            circuit_id, task_id
        );
        Ok(task_id)
    }

    async fn wait_task_done(&self, task_id: &TaskId) -> anyhow::Result<()> {
        let status_url = self.url.join(&format!("tasks/{}/status", task_id))?;
        debug!("Waiting for dispatcher task {task_id}");
        // TODO: add timeout
        loop {
            debug!(
                "Sleep another {}ms for next status polling of dispatcher task {task_id}",
                self.poll_interval.as_millis()
            );
            tokio::time::sleep(self.poll_interval).await;

            // Create a new connection for each request.
            let client = self.build_client();
            debug!("Request dispatcher task status {task_id}");
            let resp = client
                .get(status_url.clone())
                .send()
                .await
                .with_context(|| format!("Failed when requesting {status_url}"))?;
            let resp_text = resp.text().await?;
            let task_status_result = serde_json::from_str::<TaskStatusResponse>(&resp_text);
            if task_status_result.is_err() {
                debug!("Failed to parse response of {status_url}: {resp_text}");
            }
            let task_status = task_status_result
                .with_context(|| format!("Failed to parse response of {status_url}"))?;

            debug!(
                "Status of dispatcher task {task_id} is {:?}",
                task_status.status
            );
            match task_status.status {
                TaskStatus::DONE => {
                    return Ok(());
                }
                TaskStatus::FAILED => {
                    bail!("Task {} failed", task_id);
                }
                _ => {}
            }
        }
    }

    async fn get_prover_proof(&self, task_id: &TaskId) -> anyhow::Result<ProverProof> {
        debug!("Retrieving snark of task {task_id}");
        let client = self.build_client();
        let proof_url = self.url.join(&format!("tasks/{}/snark", task_id))?;
        let resp_result = client.get(proof_url.clone()).send().await;
        if resp_result.is_err() {
            let err = resp_result
                .with_context(|| format!("Failed when requesting {proof_url}"))
                .unwrap_err();
            debug!("error: {:?}", err);
            return Err(err);
        }
        let resp = resp_result.unwrap();
        let prover_proof: ProverProofResponse = resp
            .json()
            .await
            .with_context(|| format!("Failed to parse response of {proof_url}"))?;
        debug!("Snark of {task_id} is retrieved");
        Ok(prover_proof.snark.payload)
    }

    fn build_client(&self) -> ClientWithMiddleware {
        let retry_policy = ExponentialBackoff::builder().build_with_max_retries(3);
        ClientBuilder::new(reqwest::Client::new())
            // Retry failed requests.
            .with(RetryTransientMiddleware::new_with_policy(retry_policy))
            .build()
    }
}
