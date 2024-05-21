use std::fs::File;

use axiom_circuit::{
    scaffold::{AxiomCircuit, AxiomCircuitScaffold},
    types::AxiomCircuitParams,
    utils::get_provider,
};

use axiom_eth::{
    halo2_base::gates::circuit::BaseCircuitParams, halo2_proofs::dev::MockProver, halo2curves,
    rlc::circuit::RlcCircuitParams, utils::keccak::decorator::RlcKeccakCircuitParams,
};
use ethers::providers::{JsonRpcClient, Provider};
use halo2curves::bn256::Fr;

use crate::{
    circuit::WorldcoinCircuit,
    constants::MAX_PROOFS,
    types::{WorldcoinInput, WorldcoinNativeInput},
};

pub fn parse_input_from_path(path: String) -> WorldcoinInput<Fr, MAX_PROOFS> {
    let worldcoin_input: WorldcoinNativeInput =
        serde_json::from_reader(File::open(path.clone()).expect("path does not exist")).unwrap();
    worldcoin_input.into()
}

pub fn mock_test(input: WorldcoinInput<Fr, MAX_PROOFS>, should_fail: bool) -> Option<Vec<Fr>> {
    let params = RlcKeccakCircuitParams {
        rlc: RlcCircuitParams {
            base: BaseCircuitParams {
                k: 17,
                num_advice_per_phase: vec![4],
                num_lookup_advice_per_phase: vec![1],
                num_fixed: 1,
                num_instance_columns: 1,
                lookup_bits: Some(16),
            },
            num_rlc_columns: 0,
        },
        keccak_rows_per_round: 10,
    };
    let client = get_provider();

    let output = mock_with_output::<_, WorldcoinCircuit>(
        client,
        AxiomCircuitParams::Keccak(params),
        Some(input),
    );
    assert_eq!((output == None), should_fail);

    match output {
        Some(value) => {
            // (1 vk_hash  + 3 + 2 * MAX_PROOFS) * 2
            Some(value[0][0..72].to_vec())
        }
        None => None,
    }
}

pub fn mock_test_from_path(path: String, should_fail: bool) -> Option<Vec<Fr>> {
    let input = parse_input_from_path(path);
    mock_test(input, should_fail)
}

pub fn mock_with_output<P: JsonRpcClient + Clone, S: AxiomCircuitScaffold<P, Fr>>(
    provider: Provider<P>,
    raw_circuit_params: AxiomCircuitParams,
    inputs: Option<S::InputValue>,
) -> Option<Vec<Vec<Fr>>> {
    let mut runner = AxiomCircuit::<_, _, S>::new(provider, raw_circuit_params).use_inputs(inputs);
    let instances = runner.instances();

    runner.calculate_params();

    let prover = MockProver::run(17 as u32, &runner, instances).unwrap();

    match prover.verify() {
        Ok(_) => Some(runner.instances()),
        Err(_) => None,
    }
}
