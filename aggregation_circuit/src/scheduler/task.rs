// use std::fs;
// use std::sync::Arc;
// use std::thread::current;
// use std::time::Duration;
// use ethers::types::transaction::request;
// use tokio::sync::Mutex;
// use tokio::time::sleep;

// use crate::prover::ProofRequest;
// use crate::scheduler::types::ProverProof;

// use super::async_scheduler::RequestRouter;
// use super::recursive_request::RecursiveRequest;

// struct Task {
//     // task_id from dispatcher
//     task_id: Option<String>,
//     subtasks: Vec<Arc<Mutex<Task>>>,
//     request: RecursiveRequest
// }

// /**
//  * #[derive(Clone, Debug)]
// pub struct RecursiveRequest {
//     pub start: u32,
//     pub end: u32,
//     pub root: String,
//     pub grant_id: String,
//     pub claims: Vec<ClaimNative>,
//     pub params: NodeParams,
// }

//  */


// impl Task {
//     // Creates a new Task
//     fn new(request: RecursiveRequest) -> Self {
//         Self {
//             task_id: None,
//             subtasks: vec![],
//             request
//         }
//     }

//     // Adds a subtask to the current task
//     fn add_subtask(&mut self, subtask: Arc<Mutex<Task>>) {
//         self.subtasks.push(subtask);
//     }

//     // Simulates an async external call
//     async fn simulate_external_call(&self) {
//         println!("Task {} {} {} {:?}: Starting external call...", self.request.start, self.request.end, self.request.params.depth, self.request.params.node_type);
//         sleep(Duration::from_secs(5)).await; // Simulate polling delay
//         println!("Task {} {} {} {:?}: Finished external call...", self.request.start, self.request.end, self.request.params.depth, self.request.params.node_type);
//     }

//     // Executes the task and waits for its subtasks to finish
//     async fn execute(&self) {
//         // Wait for all subtasks to complete
//         let result: Vec<ProverProof> = Vec::new();

//         for subtask in &self.subtasks {
//             let subtask = subtask.lock().await;
//                 let future = Box::pin( subtask.execute());

//             let result = future.await;

//             // TODO: error handling 
//             // match result {

//             // }
//             println!("All subtasks finished for {} {} {} {:?}", self.request.start, self.request.end, self.request.params.depth, self.request.params.node_type);
//         }

//         // Now execute this task's own logic
//         self.simulate_external_call().await;
//         println!("Task {}: Completed all subtasks and self execution.", "");
//     }
// }

// // Recursive function to build the task tree
// // is_evm & round = 1 -> is_evm & round = 0
// // is_evm & round = 0 -> root aggregation
// // root aggregation & depth = INITIAL_DEPTH + 1 -> children: leaf
// // root aggregation & depth > INITIAL_DEPTH + 1 -> children: intermediate
// // intermediate aggregation & depth = INITIAL_DEPTH + 1 -> children: leaf
// // intermediate aggregation & depth > INITIAL_DEPTH + 1 -> children: intermediate
// async fn build_task_tree(current_task: &Arc<Mutex<Task>>) {
//     let deps = current_task.lock().await.request.dependencies();
//     for request in deps.iter() {
//          let subtask = Arc::new(Mutex::new(Task::new(request.clone())));
//         build_task_tree(&subtask);
//         current_task.lock().await.add_subtask(subtask);
//     }
   
// }

// #[derive(Serialize, Deserialize)]
// pub struct Request {
//     // start index of the claim, inclusive
//     start: u32,
//     // end index of the claim, exclusive
//     end: u32,
//     root: String,
//     grant_id: String,
//     // the claims vector has [start, end) claims
//     claims: Vec<ClaimNative>,

//     #[serde(skip_serializing_if = "Option::is_none")]
//     depth: Option<usize>,
//     #[serde(skip_serializing_if = "Option::is_none")]
//     is_final: Option<bool>,
//     #[serde(skip_serializing_if = "Option::is_none")]
//     for_evm: Option<bool>,
//     #[serde(skip_serializing_if = "Option::is_none")]
//     rounds: Option<usize>,
// }


// #[tokio::main]
// async fn main() {

//     let req: Request = serde_json::from_str(fs::read_to_string("./data/input_4.json"));

//     let evm_1_task = RecursiveRequest {
//         start: req.start,
//         end: req.end,
//         root: req.root,
//         grant_id: req.grant_id,
//         claims: req.claims,
//         params:  NodeType::Evm(1)
//     };
    
//     // Create root task
//     let root_task = Arc::new(Mutex::new(Task::new(evm_1_task)));

//     // Build the task tree
//     build_task_tree(&root_task);

//     // Execute the root task, which will recursively execute all subtasks
//     root_task.lock().await.execute().await;
// }
