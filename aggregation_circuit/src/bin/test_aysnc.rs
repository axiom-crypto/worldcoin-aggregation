use anyhow::bail;
use axiom_components::framework::circuit;
use axiom_eth::halo2_proofs::poly::commitment::Prover;
use axiom_eth::snark_verifier_sdk::Snark;
use ethers::types::transaction::request;
use futures::future::join_all;
use serde::{Deserialize, Serialize};
use std::any::Any;
use std::fs;
use std::sync::Arc;
use std::thread::current;
use std::time::Duration;
use tokio::sync::Mutex;
use tokio::time::sleep;
use worldcoin_aggregation::circuit_factory::v1::intermediate::WorldcoinRequestIntermediate;
use worldcoin_aggregation::circuit_factory::v1::leaf::WorldcoinRequestLeaf;
use worldcoin_aggregation::keygen::node_params::{NodeParams, NodeType};
use worldcoin_aggregation::prover::ProofRequest;
use worldcoin_aggregation::scheduler::recursive_request::RecursiveRequest;
use worldcoin_aggregation::scheduler::types::ProverProof;
use worldcoin_aggregation::types::{ClaimNative, VkNative};

struct Task {
    // task_id from dispatcher
    task_id: Option<String>,
    subtasks: Vec<Arc<Mutex<Task>>>,
    request: RecursiveRequest,
}

/**
 * #[derive(Clone, Debug)]
pub struct RecursiveRequest {
    pub start: u32,
    pub end: u32,
    pub root: String,
    pub grant_id: String,
    pub claims: Vec<ClaimNative>,
    pub params: NodeParams,
}

 */

impl Task {
    // Creates a new Task
    fn new(request: RecursiveRequest) -> Self {
        let data = fs::read_to_string("./data/vk.json").unwrap();
        let vk: VkNative = serde_json::from_str(&data).unwrap();
        Self {
            task_id: None,
            subtasks: vec![],
            request,
        }
    }

    // Adds a subtask to the current task
    fn add_subtask(&mut self, subtask: Arc<Mutex<Task>>) {
        self.subtasks.push(subtask);
    }

    // Simulates an async external call
    async fn simulate_external_call(&self) {
        println!(
            "Task {} {} {} {:?}: Starting external call...",
            self.request.start,
            self.request.end,
            self.request.params.depth,
            self.request.params.node_type
        );
        sleep(Duration::from_secs(10)).await; // Simulate polling delay
        println!(
            "Task {} {} {} {:?}: Finished external call...",
            self.request.start,
            self.request.end,
            self.request.params.depth,
            self.request.params.node_type
        );
    }

    // Executes the task and waits for its subtasks to finish
    async fn execute(&self) -> Result<ProverProof> {
        // Wait for all subtasks to complete
        // let result: Vec<ProverProof> = Vec::new();

        let futures = vec![];

        //   let subtask = self.subtasks[0].clone();
        //         let task0 = async move {
        //             let subtask = subtask.lock().await; // Lock the mutex
        //             Box::pin(subtask.execute()).await
        //         };
        //                         let subtask = self.subtasks[1].clone();

        //         let task1 = async move {
        //             let subtask = subtask.lock().await; // Lock the mutex
        //             Box::pin(subtask.execute()).await
        //         };
        //         let (result1, result2) = tokio::join!(task0, task1);
        for subtask in &self.subtasks {
            let future = async move {
                let subtask = subtask.lock().await;
                Box::pin(subtask.execute()).await
            };
            futures.push(future);
        }

        let snarks = vec![];

        // match self.subtasks.len() {
        //     1 => {
        //         let (result) = futures[0].await;
        //         let result = result.unwrap();
        //         match result {
        //             ProverProof::EvmProof(_) => bail!("in correct proof type"),
        //             ProverProof::Snark(snark) => snarks.push(snark.snark.inner)
        //         }
        //     }
        //     2 => {

        //     }
        // }
        //                 let (result1, result2) = tokio::join!(task0, task1);

        let results = join_all(futures).await;

        let snarks: Vec<Snark> = results
            .iter()
            .map(|result: &Result<ProverProof, _>| {
                let result = result.unwrap();
                match result {
                    ProverProof::EvmProof(_) => unreachable!(),
                    ProverProof::Snark(snark) => snark.snark.inner,
                }
            })
            .collect();

        let RecursiveRequest {
            start,
            end,
            grant_id,
            root,
            claims,
            params,
        } = self.request;

        let data = fs::read_to_string("./data/vk.json").unwrap();
        let vk: VkNative = serde_json::from_str(&data).unwrap();

        if params.depth == params.initial_depth {
            let leaf = WorldcoinRequestLeaf {
                start,
                end,
                depth: params.depth,
                root,
                grant_id,
                claims,
                vk, // get vk;
            };
            serde_json::to_string(&leaf).unwrap()

            // serailize WorldcoinRequestLeaf,
            // send to dispatcher
        } else {
            assert!(!snarks.is_empty());
            let request: String = match params.node_type {
                NodeType::Leaf => unreachable!(),
                NodeType::Intermediate => {
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
                    serde_json::to_string(&req)
                    // seralize
                    // send to dispatcher
                }
                NodeType::Root => {
                    // if snarks.len() != 2 {
                    //     snarks.resize(2, snarks[0].clone()); // dummy snark
                    // }
                    // let req = WorldcoinRequestRoot {
                    //     start,
                    //     end,
                    //     snarks,
                    //     depth: params.depth,
                    //     initial_depth: params.initial_depth,
                    // };
                    unreachable!()
                }
                NodeType::Evm(round) => {
                    // assert_eq!(snarks.len(), 1); // currently just passthrough
                    // let snark = snarks.pop().unwrap();
                    // let req = WorldcoinRequestEvm {
                    //     start,
                    //     end,
                    //     snark,
                    //     depth: params.depth,
                    //     initial_depth: params.initial_depth,
                    //     round,
                    // };
                    unreachable!()
                }
            };
        }

        // get the json string
        let json_string: String = "dd".to_string();
        println!(
            "All subtasks finished for {} {} {} {:?}",
            self.request.start,
            self.request.end,
            self.request.params.depth,
            self.request.params.node_type
        );

        // make call, await

        let ret_string: String = "ret".to_string();

        // parse from return result to ProverProof
        let proof: ProverProof = serde_json::from_str(&ret_string).unwrap();

        // Now execute this task's own logic
        //self.simulate_external_call().await;
        println!("Task {}: Completed all subtasks and self execution.", "");
        proof
    }
}

// Recursive function to build the task tree
// is_evm & round = 1 -> is_evm & round = 0
// is_evm & round = 0 -> root aggregation
// root aggregation & depth = INITIAL_DEPTH + 1 -> children: leaf
// root aggregation & depth > INITIAL_DEPTH + 1 -> children: intermediate
// intermediate aggregation & depth = INITIAL_DEPTH + 1 -> children: leaf
// intermediate aggregation & depth > INITIAL_DEPTH + 1 -> children: intermediate
async fn build_task_tree(current_task: &Arc<Mutex<Task>>) {
    let deps = current_task.lock().await.request.dependencies();
    for request in deps.iter() {
        let subtask = Arc::new(Mutex::new(Task::new(request.clone())));
        let future = Box::pin(build_task_tree(&subtask)).await;
        current_task.lock().await.add_subtask(subtask);
    }
}

#[derive(Serialize, Deserialize)]
pub struct Request {
    // start index of the claim, inclusive
    start: u32,
    // end index of the claim, exclusive
    end: u32,
    root: String,
    grant_id: String,
    // the claims vector has [start, end) claims
    claims: Vec<ClaimNative>,
}

#[tokio::main]
async fn main() {
    let req: Request =
        serde_json::from_str(&fs::read_to_string("./data/input_4.json").unwrap()).unwrap();

    let params = NodeParams {
        initial_depth: 0,
        depth: 2,
        node_type: NodeType::Evm(1),
    };
    let evm_1_task = RecursiveRequest {
        start: req.start,
        end: req.end,
        root: req.root,
        grant_id: req.grant_id,
        claims: req.claims,
        params: params,
    };

    // Create root task
    let root_task = Arc::new(Mutex::new(Task::new(evm_1_task)));

    // Build the task tree
    build_task_tree(&root_task).await;

    // Execute the root task, which will recursively execute all subtasks
    root_task.lock().await.execute().await;
}
