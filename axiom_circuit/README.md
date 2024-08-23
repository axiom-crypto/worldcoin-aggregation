# WorldID Proof Aggregation

This subdirectory implements Axiom client circuits for batch WorldID proof verification with Axiom.

## Folder structure

```
├── configs
│   ├──  config_{max_proof_size}_{circuit}.json     config file for client circuit
├── data
│   ├──  worldcoin_input.json           example input json for the circuit
│   └──  <others>.json                  input jsons for testing
├── src
|   ├── bin
|   ├── circuit_v1.rs                   circuit for V1 grants protocol
|   ├── circuit_v2.rs                   circuit for V2 grants protocol
|   ├── constants.rs                    constant values for the circuit
|   ├── lib.rs                          define pub mods
|   ├── mock_test.rs                    utils for unit test with mock proofs
|   ├── server_types.rs                 define structs for server requests and interacting with Axiom backend
|   ├── test.rs                         test cases
|   ├── types.rs                        define WorldcoinInput struct for the circuit
|   ├── utils.rs                        util functions
│   ├── world_id_balance_circuit.rs     circuit combining WorldID and balance verification
│   └── world_id_balance_types.rs       types for balance circuit
├── Cargo.toml
└── README.md
```

## V1 circuit

The V1 circuit verifies the WorldID Groth16 proofs in batch, and exposes the following public outputs

```
- vkeyHash - the Keccak hash of the flattened vk
- grantId
- root
- num_proofs - the number of proofs which we care about the outputs from, should satisfy 1 <= num_proofs <= max_proofs
- receiver_i for i = 1, ..., max_proofs
- nullifierHash_i for i = 1, ..., max_proofs
```

The public output size is `4 + 2 * max_proofs` for a configuration parameter `max_proofs`, which is the maximum number of claims supported at once. As a convenience to the user, fewer than `max_proofs` claims can be submitted to the prover binary and the binary will appropriately pad to satisfy the circuit.

The client circuit constrains

```
- num_proofs is in the range (0, max_proofs]
- vkeyHash is the Keccak hash of the given Groth16 vkey
- each WorldID proof is a valid Groth16 proof with the given vkey
- each WorldID proof has [root, nullfierHash, signalHash, grantId] as public inputs, where signalHash = uint256(keccak256(abi.encodePacked(receiver))) >> 8
```

### CLI

Generate proving and and verification keys for the client circuit

```
cargo run --release --bin run_v1_circuit -- --input data/worldcoin_input.json --aggregate --auto-config-aggregation -c configs/config_16.json keygen
```

Generate proof and create `output.json` and `output.snark` under `data/`. Here `output.json` is the input used for our internal backend.

```
cargo run --release --bin run_v1_circuit -- --input data/worldcoin_input.json --aggregate --auto-config-aggregation -c configs/config_16.json run
```

## V2 circuit

The V2 circuit verifies the WorldID Groth16 proofs in batch, and exposes the following public outputs

```
- vkeyHash – the Keccak hash of the flattened Groth16 vk
- grantId
- root
- claimRoot – the Keccak Merkle root of the tree whose leaves are keccak256(abi.encodePacked(receiver_i, nullifierHash_i)). Leaves with indices greater than num_proofs - 1 are given by keccak256(abi.encodePacked(address(0), bytes32(0)))
```

The configuration parameter `max_proofs` specifies the maximum number of claims in a single circuit, and must be a power of two. The client circuit constrains

```
- num_proofs to be in the range of (0, max_proofs]
- vkeyHash to be the Keccak hash of the given Groth16 vkey
- each WorldID proof to be a valid Groth16 proof with the given vkey, and [root, nullfierHash, signalHash, grantId] as public inputs where signalHash = uint256(keccak256(abi.encodePacked(receiver))) >> 8
- claiimRoot to be the Keccak Merkle root of the tree whose leaves are keccak256(abi.encodePacked(receiver_i, nullifierHash_i)). Leaves with indices greater than num_proofs - 1 are given by keccak256(abi.encodePacked(address(0), bytes32(0)))
```

### CLI

```
cargo run --release --bin run_v2_circuit -- --input data/worldcoin_input.json --aggregate --auto-config-aggregation -c configs/config_16.json keygen

cargo run --release --bin run_v2_circuit -- --input data/worldcoin_input.json --aggregate --auto-config-aggregation -c configs/config_16.json run
```

## WorldID balance circuit

The WorldID balance circuit verifies in batch that a set of WorldID users have an Ethereum balance of at least 1 ETH at a certain block number. It exposes the following public outputs

```
- vkeyHash - the Keccak hash of the flattened vk
- external_nullifier_hash
- root
- num_proofs - the number of proofs which we care about the outputs from, which should satisfy 1 <= num_proofs <= max_proofs
- block_number
- address_i for i = 1, ..., max_proofs
- nullifierHash_i for i = 1, ..., max_proofs
```

The configuration parameter `max_proofs` specifies the maximum number of claims in a single circuit, and the public output size is `5 + 2 * max_proofs`. The client circuit constrains

```
- num_proofs to be in the range (0, max_proofs]
- vkeyHash to be the Keccak hash of the given Groth16 vkey
- each WorldID proof to be a valid Groth16 proof with the given vkey, and [root, nullfierHash, signalHash, external_nullifer_hash] as public inputs, where signalHash = uint256(keccak256(abi.encodePacked(address))) >> 8
- addresses derived from the pubkeys which are recovered from the message_hash and corresponding signatures to match the addresses provided
- each address has more than 1 ETH balance at the specified block_number
```

### CLI

Generate pk and vk for the client circuit

```
cargo run --release --bin run_world_id_balance -- --input data/world_id_balance.json --aggregate --auto-config-aggregation -c configs/world_id_balance_config_16.json -p <JSON_RPC_URL_SEPOLIA> keygen
```

Generate proof and create `output.json` and `output.snark` under `data/`. Here `output.json` is the input used for our internal backend.

```
cargo run --release --bin run_world_id_balance -- --input data/world_id_balance.json --aggregate --auto-config-aggregation -c configs/world_id_balance_config_16.json -p <JSON_RPC_URL_SEPOLIA> run
```

The WorldID proof in `data/world_id_balance.json` is generated using [semaphore-rs](https://github.com/worldcoin/semaphore-rs) with `depth_30` feature flag.

## Configuration Parameters

### Maximum Batch Size

The `max_proofs` configuration parameter is the maximum number of WorldID proofs which can be verified at once. It can be set in the input JSON file; see `data/worldcoin_input.json` for an example.

### Axiom Configuration Parameters

Different configuration parameters for the Axiom system need to be adjusted for different values of `max_proofs`, mainly `k`, `lookup_bits`, `agg_params.degree`, `agg_params.lookup_bits`, `max_subqueries` (which should be set to `3*max_proofs`), `max_output`, `core_params.max_proofs`. You can find existing configs in `./configs`. The `core_params.max_proofs` value should be consistent with the one set in the Axiom config JSON.

## Development and Testing

### Testing
To run tests, use:

```
cargo test
```

This will run test cases which use inputs from `data/` for `max_proofs=16`.

### Server Setup
The binary `bin/server.rs` will provide API endpoints to fulfill requests and fulfill queries on-chain. Before starting the server, the following requirements must be met:

- Under `./data/v1/{max_proofs}`, the files `circuit.json`, `{v1_inner_circuit_id}.pk`, `{v1_inner_circuit_id}.json` should be present.
- Under `./data/v2/{max_proofs}`, the files `circuit.json`, `{v2_inner_circuit_id}.pk`, `{v2_inner_circuit_id}.json` should be present.
- Under `./data`, the file `vk.json` should be present.
- Under `~/.axiom/srs/challenge_0085`, required srs files should be present.

Start the server using the following commands:
```
export QM_URL_V1=<internal url for v1 circuit query manager>
export QM_URL_V2=<internal url for v2 circuit query manager>
export PROVIDER_URI=<JSON_RPC_URL_SEPOLIA>
cargo run --release --bin server
```

## Request endpoints
The server exposes two endpoints, `/v1` and `/v2`, which will complete client circuit proof generation, send requests to the internal Axiom backend to generate the proof which can be verified on-chain, and submit a fulfillment transaction upon proof completion.

- `/v1` uses the V1 circuit and submits a fulfillment transaction to the `WorldcoinAggregationV1` contract
- `/v2` uses the V2 circuit and submits a fulfillment transaction to the `WorldcoinAggregationV2` contract

At present, requests with `max_proofs={8, 16, 32, 64, 128}` are supported by the endpoints.

Sample requests:
```
curl -X POST  -H "Content-Type: application/json" -d @data/server_request.json localhost:8000/v1
curl -X POST  -H "Content-Type: application/json" -d @data/server_request.json localhost:8000/v2
```

Each [request](./src/server_types.rs#L13) should have `root`, `grant_id`, `num_proofs`, `max_proofs` and the list of `claims`, where each claim contains `receiver` address, `nullfilier_hash` and `proof`. One example:
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