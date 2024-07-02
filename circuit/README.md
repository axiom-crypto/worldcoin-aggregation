# Worldcoin Aggregation

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
|   ├── server_types.rs                 define structs for interacting with Axiom backend
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
- address_i for i = 1, ..., max_proofs
- nullifierHash_i for i = 1, ..., max_proofs
```

The configuration parameter `max_proofs` specifies the maximum number of claims in a single circuit, and the public output size is `4 + 2 * max_proofs`. The client circuit constrains

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

To run tests, use:

```
cargo test
```

This will run test cases which use inputs from `data/` for `max_proofs=16`.

## Request endpoint
### Setup
Under `./v1`, the files `circuit.json`, `{v1_inner_circuit_id}.pk`, `{v1_inner_circuit_id}.json` should be present.
Under `./v2`, the files `circuit.json`, `{v2_inner_circuit_id}.pk`, `{v2_inner_circuit_id}.json` should be present.
Under `~/.axiom/srs/challenge_0085`, required srs files should be present.

### Start Server
```
export QM_URL_V1=<internal url for v1 circuit query manager>
export QM_URL_V2=<internal url for v2 circuit query manager>
export PROVIDER_URI=<JSON_RPC_URL_SEPOLIA>
cargo run --release --bin server
```
### Make request
```
curl -X POST  -H "Content-Type: application/json" -d @data/worldcoin_input.json localhost:8000/v1
curl -X POST  -H "Content-Type: application/json" -d @data/worldcoin_input.json localhost:8000/v2
```
Requests to `/v1` and `/v2` endpoints will initiate the proof generation and fulfillment on-chain.