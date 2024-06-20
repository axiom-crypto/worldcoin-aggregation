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
V1 circuit verifies the WorldId Groth16 proofs in batch, and exposes the following public outputs

- vkeyHash - the Keccak hash of the flattened vk
- grantId
- root
- num_proofs - the number of proofs which we care about the outputs from, should satisfy 1 <= num_proofs <= max_proofs
- receiver_i for i = 1, …, max_proofs
- nullifierHash_i for i = 1, …, max_proofs

The public output size is 4 + 2 * max_proofs

There is a value `max_proofs` to can be configured.
The circuit supports up to `max_proofs` claims. As a convenience to the user, fewer than `max_proofs` claims can be submitted to the prover binary and the binary will appropriately pad to satisfy the circuit.

### CLI
Generate pk and vk for the client circuit

```
cargo run --release --bin run_v1_circuit -- --input data/worldcoin_input.json --aggregate --auto-config-aggregation -c configs/config_16.json keygen
```
Generate proof, and creates output.json and output.snark under data/, output.json is the input for backend system
```
cargo run --release --bin run_v1_circuit -- --input data/worldcoin_input.json --aggregate --auto-config-aggregation -c configs/config_16.json run
```

## V2 circuit
V2 circuit verifies the WorldId Groth16 proofs in batch, and exposes the following public outputs

- vkeyHash – the Keccak hash of the flattened vk
- grantId
- root
- claimRoot – the Keccak Merkle root of the tree whose leaves are keccak256(abi.encodePacked(receiver_i, nullifierHash_i)). Leaves with indices greater than num_proofs - 1 are given by keccak256(abi.encodePacked(address(0), bytes32(0)))


The public output size is constant 4.

Similarly to V1, there is a value `max_proofs` to can be configured.

### CLI
```
cargo run --release --bin run_v2_circuit -- --input data/worldcoin_input.json --aggregate --auto-config-aggregation -c configs/config_16.json keygen

cargo run --release --bin run_v2_circuit -- --input data/worldcoin_input.json --aggregate --auto-config-aggregation -c configs/config_16.json run
```

## Configurations
### max proof size
Configure max proof size (batch size of verifications) by choosing between setting the `max_proofs` value in the input json, check `data/worldcoin_input.json` as an example.
### config.json
The config json will need to be adjusted for different batch sizes, mainly `k`, `lookup_bits`, `agg_params.degree`, `agg_params.lookup_bits`, `max_subqueries` (=3*max_proofs), `max_output`, `core_params.max_proofs`. You can find existing configs in `./configs`. The `core_params.max_proofs` value should be consistent with the one in input json.

### Test
```
cargo test
```
It will run test cases which use inputs from `data/` (with max_proofs=16)

