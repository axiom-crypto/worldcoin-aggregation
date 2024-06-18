# Worldcoin Aggregation

Client circuits for worldcoin groth16 verficiation aggregation.

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
|   ├── circuit_v1.rs             v1 circuit which implements AxiomCircuitScaffold
|   ├── circuit_v2.rs             v2 circuit which implements AxiomCircuitScaffold
|   ├── constants.rs              constant values for the circuit
|   ├── lib.rs                    define pub mods
|   ├── mock_test.rs              utils for unit test with mock proofs
|   ├── test.rs                   test cases
|   ├── types.rs                  define WorldcoinInput struct for the circuit
|   └── utils.rs                  util functions
├── Cargo.toml             
└── README.md
```
## CLIs

### V1 circuit
Generate pk and vk for the client circuit
Note that if the number of claims is fewer than max_proof_size, the claims will be padded with the first claim until max_proof_size is reached.
```
cargo run --release --features max_proofs_16 --bin run_v1_circuit -- --input data/worldcoin_input.json -p http://dummy --aggregate --auto-config-aggregation -c configs/config_16.json keygen
```
Generate proof, and creates output.json and output.snark under data/, output.json is the input for backend system
```
cargo run --release --features max_proofs_16 --bin run_v1_circuit -- --input data/worldcoin_input.json -p http://dummy --aggregate --auto-config-aggregation -c configs/config_16.json run
```

### V2 circuit
```
cargo run --release --features max_proofs_16 --bin run_v2_circuit -- --input data/worldcoin_input.json -p http://dummy --aggregate --auto-config-aggregation -c configs/config_16.json keygen

cargo run --release --features max_proofs_16 --bin run_v2_circuit -- --input data/worldcoin_input.json -p http://dummy --aggregate --auto-config-aggregation -c configs/config_16.json run
```

### Configurations
#### max proof size
Configure max proof size (batch size of verifications) by choosing between `max_proofs_16, max_proofs_128, max_proofs_512, max_proofs_1024 and max_proofs_8192`
#### config.json
The config json will need to be adjusted for different batch sizes, mainly `k`, `lookup_bits`, `agg_params.degree`, `agg_params.lookup_bits`. You can find existing configs in `./configs`

### Test
```
cargo test --features max_proofs_16
```
It will run test cases which use inputs from data/ with max_proof_size=16

