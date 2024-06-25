# Worldcoin Aggregation

Client circuits for Worldcoin Groth16 verification aggregation.

## Folder structure
```
.
├── configs
│   ├──  config_{max_proof_size}_{circuit}.json     config file for client circuit
├── data
│   ├──  worldcoin_input.json     example input json for the circuit
│   └──  <others>.json            input jsons for testing
├── src
|   ├── bin
|   ├── circuit_v1.rs             V1 circuit which implements AxiomCircuitScaffold
|   ├── circuit_v2.rs             V2 circuit which implements AxiomCircuitScaffold
|   ├── constants.rs              constant values for the circuit
|   ├── lib.rs                    define pub mods
|   ├── mock_test.rs              utils for unit test with mock proofs
|   ├── test.rs                   test cases
|   ├── types.rs                  define WorldcoinInput struct for the circuit
|   └── utils.rs                  util functions
├── Cargo.toml             
└── README.md
```

## V1 circuit
V1 circuit verifies the WorldID Groth16 proofs in batch, and exposes the following public outputs

- vkeyHash - the Keccak hash of the flattened vk
- grantId
- root
- num_proofs - the number of proofs which we care about the outputs from, should satisfy 1 <= num_proofs <= max_proofs
- receiver_i for i = 1, …, max_proofs
- nullifierHash_i for i = 1, …, max_proofs

The public output size is 4 + 2 * max_proofs

There is a value `max_proofs` which can be configured.
The circuit supports up to `max_proofs` claims. As a convenience to the user, fewer than `max_proofs` claims can be submitted to the prover binary and the binary will appropriately pad to satisfy the circuit.

The client circuit constrains
```
- num_proofs to be in the range of (0, max_proofs]
- vkeyHash to be the Keccak hash of the given vkey
- each WorldID proof to be a valid Groth16 proof with the given vkey, and [root, nullfierHash, signalHash, grantId] as public inputs where signalHash = uint256(keccak256(abi.encodePacked(receiver))) >> 8
```

### CLI
Generate pk and vk for the client circuit

```
cargo run --release --bin run_v1_circuit -- --input data/worldcoin_input.json --aggregate --auto-config-aggregation -c configs/config_16.json keygen
```
Generate proof and create `output.json` and `output.snark` under `data/`. Here `output.json` is the input used for our internal backend.
```
cargo run --release --bin run_v1_circuit -- --input data/worldcoin_input.json --aggregate --auto-config-aggregation -c configs/config_16.json run
```

## V2 circuit
V2 circuit verifies the WorldID Groth16 proofs in batch, and exposes the following public outputs

- vkeyHash – the Keccak hash of the flattened vk
- grantId
- root
- claimRoot – the Keccak Merkle root of the tree whose leaves are keccak256(abi.encodePacked(receiver_i, nullifierHash_i)). Leaves with indices greater than num_proofs - 1 are given by keccak256(abi.encodePacked(address(0), bytes32(0)))


The public output size is constant 4.

Similarly to V1, there is a value `max_proofs` which can be configured.

The client circuit constrains
```
- num_proofs to be in the range of (0, max_proofs]
- vkeyHash to be the Keccak hash of the given vkey
- each WorldID proof to be a valid Groth16 proof with the given vkey, and [root, nullfierHash, signalHash, grantId] as public inputs where signalHash = uint256(keccak256(abi.encodePacked(receiver))) >> 8
- claiimRoot to be the Keccak Merkle root of the tree whose leaves are keccak256(abi.encodePacked(receiver_i, nullifierHash_i)). Leaves with indices greater than num_proofs - 1 are given by keccak256(abi.encodePacked(address(0), bytes32(0)))
```

### CLI
```
cargo run --release --bin run_v2_circuit -- --input data/worldcoin_input.json --aggregate --auto-config-aggregation -c configs/config_16.json keygen

cargo run --release --bin run_v2_circuit -- --input data/worldcoin_input.json --aggregate --auto-config-aggregation -c configs/config_16.json run
```

## World ID balance circuit
World ID balance circuit verifies the following statement in batch: the WorldID user has an Ethereum balance of at least 1 ETH at a certain block number, and exposes the following public outputs

- vkeyHash - the Keccak hash of the flattened vk
- external_nullifier_hash
- root
- num_proofs - the number of proofs which we care about the outputs from, which should satisfy 1 <= num_proofs <= max_proofs
- address_i for i = 1, …, max_proofs
- nullifierHash_i for i = 1, …, max_proofs

The public output size is 4 + 2 * max_proofs

Similarly to V1 & V2, there is a value `max_proofs` which can be configured.

The client circuit constrains
```
- num_proofs to be in the range of (0, max_proofs]
- vkeyHash to be the Keccak hash of the given vkey
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

## Configurations
### max proof size
Configure max proof size (batch size of verifications) by setting the `max_proofs` value in the input json, check `data/worldcoin_input.json` as an example.
### config.json
The config json will need to be adjusted for different batch sizes, mainly `k`, `lookup_bits`, `agg_params.degree`, `agg_params.lookup_bits`, `max_subqueries` (=3*max_proofs), `max_output`, `core_params.max_proofs`. You can find existing configs in `./configs`. The `core_params.max_proofs` value should be consistent with the one in input json.

### Test
```
cargo test
```
It will run test cases which use inputs from `data/` (with max_proofs=16)

