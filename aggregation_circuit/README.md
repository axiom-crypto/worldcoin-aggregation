# WorldID Proof Aggregation

This subdirectory implements circuits for batch WorldID proof verification.

## Folder structure

```
├── data
│   ├──  vk.json                        the json for the vk
│   └──  generated_proofs_{size}.json   example input for different sizes
├── src
|   └── bin
|         ├── keygen.rs                 entry point for starting keygen
|         |── local_server.rs           entry point for starting server which generates snarks locally
|         |── prover_server.rs          entry point for starting prover which generates snark based on request
|         └── scheduler_server.rs       entry point for starting scheduler which coordinates the execution on remote infra
|   ├── circuit_factory                 factories to build circuits
|   ├── circuits                        circuit implementation for the V1 circuit and the V2 circuit
|   ├── keygen                          functions to conduct keygen
|   ├── prover                          prover struct which can load/manage pk, build circuit and generate snark
|   └── scheduler                       schedulers that can coordinate the executions
|         ├── local_scheduler.rs        a scheduler that generate snarks synchronously in local
|         ├── async_scheduler.rs        a scheduler that talks to remote dispatcher services or provers asynchronously 
|         └── executor                  an executor which talks to a dispatcher service for executing the proving tasks, and 
|                                       polls results until the tasks reached terminal status (DONE of FAILED)
|   └── toolings                        toolings for select instance types for prover
├── Cargo.toml
└── README.md
```

## V1 circuit

The V1 circuit verifies the WorldID Groth16 proofs in batch, and exposes the keccak hash of the following outputs

```
- vkeyHash - the Keccak hash of the flattened vk
- grantId
- root
- num_proofs - the number of proofs which we care about the outputs from, should satisfy 1 <= num_proofs <= max_proofs
- receiver_i for i = 1, ..., max_proofs
- nullifierHash_i for i = 1, ..., max_proofs
```
As a convenience to the user, fewer than `max_proofs` claims can be submitted to the prover binary and the binary will appropriately pad to satisfy the circuit.


### High level approach ###
There are 4 types of circuits
- **WorldcoinLeafCircuit** -  It has `max_depth` which decides the max capacity to be  `2**depth` claims. It has `start` (inclusive) and `end` (exclusive) index to indicates the indexes of claims this circuit is handling. It constraints constrains
    - `start` and `end` are in `[0, 2**64)`
    - `num_proofs (end - start)` falls between `[0, 2**max_depth]`
    - each claim verifies with the loaded `vk` and public inputs `[root, nullifier_hash, signal_hash, grant_id]`, where ` signalHash = uint256(keccak256(abi.encodePacked(receiver))) >> 8`
    - The public outputs are `[start, end, vk_hash_hi, vk_hash_lo, grant_id, root, ...receivers, ...nullifier_hashes]`
- **WorldcoinIntermediateAggregationCircuit** - It aggregates either two WorldcoinLeafCircuits or WorldcoinIntermediateAggregationCircuits, and also enforce constraints between the children snarks
    - The two children either link together, where the `end` of the 1st shard equal `start` of the 2nd shard, or the second shard is a dummy shard
    - It check vkey, grant_id, root are the same for both shards
    - It has the same format of public outputs as the leaf circuit.
- **WorldcoinRootAggregationCircuit** - It is similar to WorldcoinIntermediateAggregationCircuit in terms of aggregation, but it exposes the keccak hash of `[vk_hash_hi, vk_hash_lo, grant_id, root, num_proofs, ...receivers, ...nullifier_hashes]` as public outputs.
- **WorldcoinEvmCircuit** - It is a passthrough circuit for the onchain verifier.
The claims are divided into WorldcoinLeafCircuits and then aggregated until we have one single WorldcoinRootAggregationCircuit. The final public output is the keccak hash of `[vk_hash_hi, vk_hash_lo, grant_id, root, num_proofs, ...receivers, ...nullifier_hashes]`.

## V2 circuit
The V2 circuit set up is similar to the V1 circuit, it has public outputs

```
- vkeyHash – the Keccak hash of the flattened Groth16 vk
- grantId
- root
- claimRoot – the Keccak Merkle root of the tree whose leaves are keccak256(abi.encodePacked(receiver_i, nullifierHash_i)). Leaves with indices greater than num_proofs - 1 are given by keccak256(abi.encodePacked(address(0), bytes32(0)))
```

The configuration parameter `max_proofs` specifies the maximum number of claims in a single circuit, and must be a power of two. 

- **WorldcoinLeafCircuitV2** -  It has all the constraints that the V1 circuit has.
    - In addition, it calculates the claim root for the subtree.
    - The public outputs are `[start, end, vk_hash_hi, vk_hash_lo, grant_id, root, claim_root_hi, claim_root_lo]`
- **WorldcoinIntermediateAggregationCircuitV2** -  It has all the constraints that the V1 circuit has.
    - In addition, it calculates `claim_root = keccak(left_child, right_child)`.
    - It has the same public outputs formats as `WorldcoinLeafCircuitV2`.
- **WorldcoinRootAggregationCircuitV2** - It is similar to `WorldcoinIntermediateAggregationCircuitV2` in terms of aggregation, but it exposes the keccak hash of `[vk_hash_hi, vk_hash_lo, grant_id, root, num_proofs, claim_root_hi, claim_root_lo]` as public outputs.
- **WorldcoinEvmCircuit** - It is a passthrough circuit for the onchain verifier.
The claims are divided into `WorldcoinLeafCircuitV2`s and then aggregated until we have one single `WorldcoinRootAggregationCircuitV2`. The final public outputs are `[vk_hash_hi, vk_hash_lo, grant_id, root, num_proofs, claim_root_hi, claim_root_lo]`.

## Scheduler and Prover Infrastructure
To generate proofs in parallel, we define three key roles:

- **Scheduler**
The scheduler receives a task and handles the process of breaking the task into smaller subtasks, resolving dependencies and necessary input data between the tasks, and then sending concurrent proof requests to the dispatcher, waiting for task completion, and using completed tasks to start downstream tasks. 

- **Dispatcher**
The dispatcher handles container orchestration by receiving tasks, allocating necessary infrastructure resources (such as EC2 instances or Kubernetes pods), starting containers for the prover, executing the tasks, and retrieving the resulting proofs.

- **Prover**
 prover is designed to be serverless and can be run from a blind docker container as long as it is given the correct auxiliary files (pinning JSON and proving key large files, identified by circuit ID).

This repository includes implementations for the Scheduler and Prover. The Dispatcher component is designed to be flexible, allowing users to plug in and integrate their own infrastructure solutions as needed.

## Configuration Parameters

### Maximum Batch Size

The `max_proofs` configuration parameter is the maximum number of WorldID proofs which can be verified at once. It can be set in the input JSON file; see `data/generated_proofs_128.json` for an example.

## Development and Testing
### Keygen
Run keygen will generate proving keys, verifying keys and the on-chain verifier contract.

Before starting keygen, define an intent like `configs/intents/2.yml`, it has the following format
```
k_at_depth: [20, 20, 20, 20]   -> the K used in each depth, where the final evm round uses k_at_depth[0] and leaf circuit uses k_at_depth[k_at_depth.len() - 1]
params:
  node_type:
    Evm: 1  -> extra round we are doing WorldcoinEvmCircuit, it is typically set to 1
  depth: 1  -> 1 << depth is the max_proofs we are handling
  initial_depth: 0  -> 1 << initial_depth is the max_proofs a single leaf circuit can handle

``` 

Then run keygen using the following command
```
cargo run --release --bin keygen --features "keygen, v1(or v2)" -- --srs-dir ${SRS_DIR} --intent ${INTENT_YML_PATH} --tag ${CIDS_NAME} --data-dir ${CIRCUIT_DATA_DIR}
```

- You need to have the corresponding `kzg_bn254_{k}`.srs under the ${SRS_DIR}, you can download the srs from the [Axiom](s3://axiom-crypto/challenge_0085/) public s3 bucket
- You pks, vks and .sol will be written to ${CIRCUIT_DATA_DIR}, together with a ${CIDS_NAME}.cids file which shows the computation tree.

### Start Scheduler and Sample Request
To start scheduler_server
```
cargo run --release --features "v1(or v2)" --bin scheduler_server -- --cids-path ${CIDS_PATH} --executor-url ${DISPATCHER_URL}
```
To send sample request:
```
curl -X POST http://localhost:8000/tasks -H "Content-Type: application/json" -d  @data/generated_proofs_128.json 
```

Each request should have `root`, `grant_id`, `num_proofs`, `max_proofs` and the list of `claims`, where each claim contains `receiver` address, `nullfilier_hash` and `proof`. One example:
```
{
  "root": "12439333144543028190433995054436939846410560778857819700795779720142743070295",
  "grant_id": "30",
  "num_proofs": 2,
  "max_proofs": 16,
  "claims": [
    {
      "receiver": "0xff9db18c23be01D48DCF1fE182f4807055ae8cA2",
      "nullifier_hash": "21294919666276076011035787158136769959318829071812973005197954290733822302380",
      "proof": [
        "19948547122086334894689325645680910374301022582555626047089468872550356701348",
        "6362289764495762031291485042629552885766242716159339697483919575876761663887",
        "12317072617562704121665824087528933441231019811489677371494230327903596083401",
        "15337252639786931925369532534863856807942067245134861343169827164963211645183",
        "7949760175864257885824108095736762655812039267855215663171263181543943914662",
        "10989109543847136625154415890014728205912311878476742612878411879448476913324",
        "7847594500848555155310078556331504334829185538025208292983008028678812984187",
        "10768498842689083083534029252274093386835987853753326810579921208375319434106"
      ]
    },
    ...
  ]
}
```

### Start Prover
To start prover_server
``` 
cargo run --release --bin prover_server  --features "asm, v1(or v2)" -- --circuit-data-dir ${CIRCUIT_DATA_DIR} --srs-dir ${SRS_DIR} --cids-path ${CIDS_PATH}
```

