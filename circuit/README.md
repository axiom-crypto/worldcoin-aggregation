# World ID Proof Aggregation

This subdirectory implements ZK circuits and backend prover endpoints for batch World ID proof verification.

## Summary

- [Batch World ID Verification Circuits](#batch-worldid-verification-circuits)
- [Prover Backend Architecture](#prover-backend-architecture)

## Folder structure

```
├── data
│   ├──  vk.json                        The json for the verification key
│   └──  generated_proofs_{size}.json   Example inputs for different sizes
├── src
|   └── bin
|         ├── keygen.rs                 The entry point for starting keygen
|         |── local_server.rs           The entry point for starting a server which generates SNARKs locally
|         |── prover_server.rs          The entry point for starting a prover which generates SNARKs based on request
|         └── scheduler_server.rs       The entry point for starting a scheduler that coordinates execution across remote infrastructure
|   ├── circuit_factory                 The factories to build circuits
|   ├── circuits                        The circuit implementations for the aggregation circuits
|   ├── keygen                          The functions to conduct keygen
|   ├── prover                          A Prover struct that can load and manage proving keys, build circuits, and generate SNARKs.
|   └── scheduler                       The schedulers that break down tasks and coordinate the executions
|         ├── local_scheduler.rs        A scheduler that generates SNARKS synchronously in local
|         ├── async_scheduler.rs        A scheduler that talks to remote executors for execution
|         └── executor                  An executor which talks to a dispatcher service for executing the proving tasks, and
|                                       polls results until the tasks reach terminal statuses
|   └── toolings                        Tooling to select instance types for the prover
├── Cargo.toml
└── README.md
```

## Batch World ID Verification Circuits

The architecture for the SNARK circuits used in the V1 and V2 designs follow the same MapReduce
structure which uses SNARK aggregation.

![Circuit Diagram](./assets/Worldcoin%20Circuit%20Diagram.png)

We give a high-level overview before discussing the details of the circuits.
The topmost `Evm` circuit generates the proof that is verified on-chain in a smart contract.
This circuit proves a batch of claims for WLD grants by aggregating the proofs of smaller batches of claims. An arrow A → B in the diagram means that circuit A contains constraints that verify a proof of circuit B. The core claim verification logic for a small batch of claims is proven in the `Leaf` circuit. Multiple `Leaf` circuit proofs are aggregated in a binary tree structure, with some additional reduce logic to enforce consistency. Several additional rounds of aggregation are done to compress the final proof size to lower the final on-chain verification gas cost.

We now proceed to discuss the details of the V1 and V2 circuits within this framework.

### V1 Circuit Design

The V1 circuit verifies the World ID Groth16 proofs in batch, and exposes as a public output the Keccak hash of the following quantities.

- `vkey_hash` - the Keccak hash of the flattened vk
- `num_claims` - the number of claims, which should satisfy `1 <= num_claims <= MAX_NUM_CLAIMS`
- `root`
- `grant_ids_i` for `i = 1, ..., MAX_NUM_CLAIMS`
- `receivers_i` for `i = 1, ..., MAX_NUM_CLAIMS`
- `nullifierHashes_i` for `i = 1, ..., MAX_NUM_CLAIMS`

As a convenience to the user, fewer than `MAX_NUM_CLAIMS` claims can be submitted to the prover.

To implement the V1 circuit, we use the following 4 types of circuits:

- **WorldcoinLeafCircuit** - It has configuration parameter `max_depth` which sets the maximum number of claims that the circuit can prove to be `2 ** max_depth`. It has `start` (inclusive) and `end` (exclusive) indexes for the claims this circuit is handling. It constrains
  - `start` and `end` are in `[0, 2**64)`
  - `end - start` lies in `(0, 2**max_depth]`
  - each claim verifies with the Groth16 verifying key `vk` and inputs `[root, nullifier_hash, receiver, grant_id]`
  - The public IO consists of `[start, end, vk_hash_hi, vk_hash_lo, root, ...grant_ids, ...receivers, ...nullifier_hashes]`
- **WorldcoinIntermediateAggregationCircuit** - It aggregates either two WorldcoinLeafCircuit proofs or two WorldcoinIntermediateAggregationCircuit proofs, depending on the circuit's depth in the aggregation tree, and also enforce constraints between the public IO of the two aggregated child proofs:
  - The two child proofs either link together, where the `end` of the 1st proof equals the `start` of the 2nd proof, or the 2nd proof is a dummy
  - It checks `vk, root` are the same in both children
  - It has the same format of public IO as the leaf circuit.
- **WorldcoinRootAggregationCircuit** - It is similar to WorldcoinIntermediateAggregationCircuit in terms of aggregation, but its public IO consists of only the keccak hash of
  `[vk_hash_hi, vk_hash_lo, root, num_claims, ...grant_ids, ...receivers, ...nullifier_hashes]` where `num_claims = end - start` is the total number of claims this proof has verified.
- **WorldcoinEvmCircuit** - It aggregates either a single WorldcoinRootAggregationCircuit or a single WorldcoinEvmCircuit, depending on the circuit's depth in the aggregation tree. The only purpose of this circuit is to compress the final proof size to lower the final on-chain verification cost.
  The final public IO is the keccak hash of `[vk_hash_hi, vk_hash_lo, root, num_claims, ...grant_ids, ...receivers, ...nullifier_hashes]`.
  - In practice we use two WorldcoinEvmCircuits to compress the final proof size.

### V2 Circuit Design

The V2 circuit design is similar to the V1 circuit. It has public outputs

- `vkey_hash` – the Keccak hash of the flattened Groth16 verifying key `vk`
- `root`
- `claim_root` – the Keccak Merkle root of the tree whose leaves are `keccak256(abi.encodePacked(grant_ids_i, receivers_i, nullifierHashes_i))`. Leaves with indices greater than `num_claims - 1` are given by `keccak256(abi.encodePacked(uint256(0), address(0), bytes32(0)))`, where `1 <= num_claims <= MAX_NUM_CLAIMS`.

The V2 design is implemented through the following circuits:

- **WorldcoinLeafCircuitV2** - It has all the constraints that the WorldcoinLeafCircuitV1 has.
  - In addition, it calculates the claim root for the subtree of depth `max_depth`.
  - The public IO is `[start, end, vk_hash_hi, vk_hash_lo, root, claim_root_hi, claim_root_lo]`
- **WorldcoinIntermediateAggregationCircuitV2** - It has all the constraints that the WorldcoinIntermediateAggregationCircuitV1 has.
  - In addition, it calculates `claim_root = keccak(left_child, right_child)`, where `left_child` and `right_child` are the claim roots of the two child proofs that were aggregated.
  - It has the same public outputs formats as `WorldcoinLeafCircuitV2`.
- **WorldcoinRootAggregationCircuitV2** - It is similar to `WorldcoinIntermediateAggregationCircuitV2` in terms of aggregation, but the public IO consists of only the keccak hash of `[vk_hash_hi, vk_hash_lo, root, num_claims, claim_root_hi, claim_root_lo]` where `num_claims = end - start` is the total number of claims this proof has verified.
- **WorldcoinEvmCircuit** - It aggregates either a single WorldcoinRootAggregationCircuit or a single WorldcoinEvmCircuit, depending on the circuit's depth in the aggregation tree. The only purpose of this circuit is to compress the final proof size to lower the final on-chain verification cost.
  The final public IO is the keccak hash of `[vk_hash_hi, vk_hash_lo, root, num_claims, claim_root_hi, claim_root_lo]`.
  - In practice we use two WorldcoinEvmCircuits to compress the final proof size.

### Proving and Verifying Key Generation

Before generating SNARK proofs for the circuits above, you must first generate the proving and verifying keys for all circuits in the aggregation tree. This should be done once: the proving and verifying keys of the circuits will not change unless the circuits themselves are changed.
The verifying key is a unique identifier for the circuit, and we define the **Circuit ID** of a circuit to be the Blake3 hash of the serialized bytes of its verifying key.

To generate the proving keys, verifying keys and the on-chain verifier contract for the circuits described above, follow these steps:

1. Download the KZG trusted setup that we use with [this script](https://github.com/axiom-crypto/axiom-eth/blob/main/trusted_setup_s3.sh).

```
bash trusted_setup_s3.sh
```

For convenience, Axiom hosts the [Phase 1 perpetual powers of tau](https://github.com/privacy-scaling-explorations/perpetualpowersoftau) trusted setup formatted for halo2 in a public [S3 bucket](s3://axiom-crypto/challenge_0085/).
You can read more about the trusted setup we use and how it was generated [here](https://docs.axiom.xyz/docs/transparency-and-security/kzg-trusted-setup).

The trusted setup will be downloaded to a directory called `params/` by default. You can move the directory elsewhere. We'll refer to the directory as `$SRS_DIR` below.

2. Define an intent YAML file.

The intent file provides the minimal configuration parameters to both determine the shape of the aggregation tree and the configuration of each circuit. During keygen, the circuits are auto-tuned for best performance based on the intent parameters.

A sample YAML file is provided in [`configs/intents/2.yml`](configs/intents/2.yml).

The intent file has the following format:

```
k_at_depth: [20, 20, 20, 20]
params:
  node_type:
    Evm: 1
  depth: 1
  initial_depth: 0
```

- `k_at_depth`: the circuit degree at each tree depth, starting from the final `WorldcoinEvmCircuit` at index `0` and ending in the `WorldcoinLeafCircuitV{1,2}` at `k_at_depth.len() - 1`. Here degree `k` means that the circuit will have `2 ** k` rows in its PLONKish arithmetization.
- `Evm: num_extra_rounds` means there will be `num_extra_rounds + 1` `WorldcoinEvmCircuit`s in the aggregation tree. Typically this is set to 1.
- `depth`: sets `MAX_NUM_CLAIMS` to `2 ** depth`.
- `initial_depth`: sets the maximum number of claims that can be verified in the `WorldcoinLeafCircuit` to `2 ** initial_depth`.

  The length of `k_at_depth` must equal `depth - initial_depth + num_extra_rounds + 2`.

The intent YAML files used for benchmarking are located in the `configs/intents` directory, named as `{MAX_NUM_CLAIMS}.yml`.

3. Run keygen.

We assume the KZG trusted setup files are located in `${SRS_DIR}` and named `kzg_bn254_{k}.srs` for circuit degree `k`. You can now run keygen using the following command:

```
cargo run --release --bin keygen --features "keygen, v1(or v2)" -- --srs-dir ${SRS_DIR} --intent ${INTENT_YML_PATH} --tag ${CIDS_NAME} --data-dir ${CIRCUIT_DATA_DIR}
```

where the feature `v1` or `v2` should be specified based on whether V1 or V2 circuits should be used.

The resulting proving keys, verification keys, and on-chain verification contract will be written to `${CIRCUIT_DATA_DIR}`, together with a `${CIDS_NAME}.cids` JSON file which encodes the aggregation tree as a list of the circuit IDs at each depth of the tree. The `.cids` file extension is an acronym standing for Circuit IDs -- the file type is JSON, and the extension is used to emphasize this is a special file containing the circuit IDs of an aggregation tree. The `${CIDS_NAME}` can be any string. It is meant to be an operator specified identifier to distinguish between different aggregation trees (e.g., which have different tree structures or circuit configurations). All nodes at the same depth in the aggregation tree use the same circuit, so they all have the same circuit ID. The `*.cids` file is context-dependent: it only works for the World ID verification circuits in this repository. The file is not meant to be interoperable with other generic Halo2 circuits.

## Prover Backend Architecture

We provide tooling for an external operator to generate proofs for the Worldcoin circuits in a distributed system. This involves three key roles:

- **Scheduler**
  The scheduler receives the top-level request to generate a SNARK proof for the verification of up to `MAX_NUM_CLAIMS` WLD grant claims. The scheduler then breaks this request into smaller subtasks corresponding to the nodes in the proof aggregation tree. The scheduler prepares and sends the requests to generate proofs for these smaller subtasks to the **Dispatcher** in a fully asynchronous manner. The scheduler manages task dependencies, sending new requests once dependency tasks have completed.

- **Dispatcher**
  The dispatcher handles container orchestration by receiving tasks, allocating necessary infrastructure resources (such as EC2 instances or Kubernetes pods), starting containers for the **Prover**, executing the tasks, and retrieving the resulting proofs. The dispatcher is also responsible for caching proofs that have already been generated. The dispatcher API is compatible with both auto-scaling and dedicated infrastructure solutions.

- **Prover**
  The prover is designed to be serverless and can be run from a blind docker container as long as it is given the correct auxiliary files (circuit configuration JSON and proving key files, identified by circuit ID).

This repository includes implementations for the Scheduler and Prover. These can interoperate with an operator-written Dispatcher, which will need to integrate with the operator's on-prem or cloud infrastructure solution.

We now describe the architecture of these components in more detail.

### Scheduler

The scheduler provides the highest level API for interacting with the backend. It receives the request for an entire proving workload, whose final output is the serialized bytes of a SNARK proof proving `MAX_NUM_CLAIMS` WLD grant claims. To achieve this, the scheduler must schedule proving tasks according to a computation DAG, namely the aggregation tree structure depicted in [Batch World ID Verification Circuits](#batch-worldid-verification-circuits).

We provide two implementations of the scheduler:

- **Local Scheduler**: This scheduler runs on the local machine and generates proofs sequentially on the same machine. This scheduler does not require a separate dispatcher or proving server. It is intended for testing and development purposes.
- **Async Scheduler**: This scheduler is designed for production use in a distributed computing system. The async scheduler does not perform any proof generation. Instead, it makes concurrent asynchronous calls to the **Dispatcher** to request proof generation. All proof requests that do not have unresolved dependencies are executed in parallel, and each request is polled for completion. Once all dependencies of an unstarted task are completed, the scheduler prepares the task input and requests a proof of the task. The maximum number of concurrent tasks is configurable.

The scheduler receives requests via a REST API.

#### Commands

To start the Scheduler, run the command:

```
cargo run --release --features $VERSION --bin scheduler_server -- --cids-path ${CIDS_PATH} --executor-url ${DISPATCHER_URL}
```

where `$VERSION` is the version of the circuits to use, either `v1` or `v2`.
The `${CIDS_PATH}` is the path to the JSON file output by the keygen command, which stores the
circuit IDs at each depth of the aggregation tree. The `${DISPATCHER_URL}` is the URL of the dispatcher REST API server.

To send sample request:

```
curl -X POST http://localhost:8000/tasks -H "Content-Type: application/json" -d  @data/generated_proofs_128.json
```

Each request should have `root`, and the list of `claims`, where each claim contains `grant_id`, `receiver` address, `nullifier_hash` and `proof`. The scheduler will reject the request if `claims` is empty or if `num_claims` exceeds the `MAX_NUM_CLAIMS` set in the circuit configurations that it was started with.

An example request looks like:

```
{
  "root": "12439333144543028190433995054436939846410560778857819700795779720142743070295",
  "claims": [
    {
      "receiver": "0xff9db18c23be01D48DCF1fE182f4807055ae8cA2",
      "grant_id": "30",
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

### Dispatcher

⚠ ️This repository **does not** provide an implementation of the dispatcher, as the dispatcher is heavily tied to the precise backend infrastructure used by the operator. Below we describe the required functionality of such a dispatcher and the API that it must conform to in order to be integrated with the rest of the backend architecture.

The dispatcher is responsible for container orchestration of the SNARK prover nodes. The dispatcher may be implemented as part of an autoscaling system of empheral nodes, a system of persistent nodes, or a combination of both.

A dispatcher request is a request for the generation of a SNARK proof for a single circuit. The dispatcher does not handle any scheduling and has no context about workload dependencies. The dispatcher request contains:

- the circuit ID, a unique identifier for the circuit
- the input that should be used to generate the proof for the circuit.

The dispatcher is then expected to:

- Create and allocate a new container for the prover.
- Mount the necessary trusted setup files in the container.
- Using the circuit ID, fetch the proving key and circuit configuration files for the circuit (e.g., from an object store such as AWS S3 or a distributed file system) and mount them in the container. For optimal performance, we recommend that the proving key is mounted directly into memory using `ramfs` or `tmpfs` -- the prover binary needs to read and deserialize the proving key, which is much faster if the file is in memory.
- Pull the proving server docker image.
- Start the proving server in the container, with arguments pointing to the locations of the trusted setup files, the proving key, and the circuit configuration files.

The dispatcher _should_ also implement a caching layer to avoid redundant proof generation. A proof can be uniquely identified by `(circuitId, Hash(input))`. The caching layer can be implemented via connection to a persistent database. Since the size of the proof input itself may be large, we recommend that the proof input is cached separately, for task recovery and debugging, using an object store such as AWS S3.

The operator can choose how to implement the dispatcher to fulfill these requirements. Options include: using the AWS SDK to interact directly with AWS cloud, using Kubernetes to manage containers, or using a custom solution.

#### Dispatcher API Interface

For integration with the scheduler, the dispatcher must be implemented as a web server conforming to the following REST APIs.

##### POST `/tasks`

- **Request Body:**
  - **circuitId**: Unique identifier for a circuit, defined as the Blake3 hash of the serialized bytes of the circuit's verifying key. This value is globally unique among all circuits handled by the Dispatcher.
  - **input**: Accepts a JSON object for flexibility. The Dispatcher should forward it to the proving binary without processing its content.
  - **[optional] ForceProve**: A proof can be uniquely identified by `(circuitId, Hash(input))`. By default, all proofs are cached. If the Dispatcher receives a request, it will return the cached proof directly. If this field is set to `true`, the system will force a new proof generation even if a cached proof already exists.
- **Response:**
  - **taskId**: Uniquely identifies the proof task. The Scheduler will poll `/tasks/:taskId/status` every 5-10 seconds to check if the task is completed.

##### GET `/tasks/:taskId/status`

- **Response:**
  - **status**: Indicates the current task status. Possible values:
    - `PENDING`: Task is created but waiting for resources.
    - `PREPARING`: A container is allocated, but setup is still in progress (e.g., downloading pkey).
    - `PROVING`: The proving job is currently running.
    - `DONE`: The job is completed, and the SNARK proof is available.
    - `FAILED`: The task failed.
  - **createdAt**: Timestamp when the task was created.
  - **updatedAt**: Timestamp when the task status was last updated.

##### GET `/tasks/:taskId/snark`

- **Response:**
  - **snark**: Returns the proof file.

### Prover

The prover is the most computation intensive component of the system. It is responsible for generating the SNARK proof for a given circuit. We implement the prover as a REST API server
which can generate proofs for any of the circuits described in [Batch World ID Verification Circuits](#batch-worldid-verification-circuits). The prover accepts a typeless request consisting of the circuit ID and the proof input. The proving server infers the circuit type from the circuit ID and proof input to determine which circuit to prove for.

The prover first loads configuration files and the proving key from `${CIRCUIT_DATA_DIR}` directory, using the circuit ID to determine which files to load. The prover will store the proving key in memory after the first load, keeping it in memory for future proof requests until it is told via API request to reset the memory. Because we expect the proving time of a single circuit to not exceed typical connection disconnect thresholds, the proving server keeps the HTTP connection open for the duration of the proving process. Once proving is complete, the prover returns the proof in the response. The prover does not cache any proof results.

#### Prover API Interface

##### GET `/build_info`

A heartbeat endpoint to check if the proving server is running.

- **Response:**
  - **build_info**: Returns `"alive"`.

##### POST `/tasks`

The endpoint to send a request to generate a proof. The request body is a JSON object containing the circuit ID and the proof input:

- **Request Body:**
  - **circuit_id**: The circuit ID.
  - **input**: The proof input. The input format depends on the circuit type.
- **Response:**
  - **payload**: The proof, either as a base64 encoding of the serialized bytes of the SNARK proof, or as the hex string of the proof, intended to be used as calldata sent to the on-chain verifier contract.

##### POST `/reset`

Clears everything stored in memory (trusted setup, proving keys, circuit configurations).
This is useful for avoiding out-of-memory errors.

##### POST `/internal/circuit-data`

Internal endpoint, using by dispatcher, to tell the prover to load the proving key and circuit configuration files for the given circuit ID into memory.

- **Request Body:** same as for `/tasks`

#### Commands

To start the Prover, run the command:

```
cargo run --release --bin prover_server  --features "asm, <v1 or v2>" -- --circuit-data-dir ${CIRCUIT_DATA_DIR} --srs-dir ${SRS_DIR} --cids-path ${CIDS_PATH}
```

The `${CIDS_PATH}` is the path to the JSON file output by the keygen command, which stores the
circuit IDs at each depth of the aggregation tree.
