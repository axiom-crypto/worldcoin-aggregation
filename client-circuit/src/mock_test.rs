use std::fs::File;

use axiom_circuit::{
    scaffold::{AxiomCircuit, AxiomCircuitScaffold},
    types::AxiomCircuitParams,
    utils::get_provider,
};

use axiom_eth::{
    halo2_base::gates::circuit::BaseCircuitParams, halo2_proofs::dev::MockProver, halo2curves,
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

pub fn mock_test(input: WorldcoinInput<Fr, MAX_PROOFS>, should_fail: bool) {
    let client = get_provider();
    let circuit_params: BaseCircuitParams = BaseCircuitParams {
        k: 14,
        num_advice_per_phase: vec![4],
        num_lookup_advice_per_phase: vec![1],
        num_fixed: 1,
        num_instance_columns: 1,
        lookup_bits: Some(13),
    };
    let output = mock_with_output::<_, WorldcoinCircuit>(
        client,
        AxiomCircuitParams::Base(circuit_params),
        Some(input),
    );
    assert_eq!((output == None), should_fail);
    if output != None {
        // vk (25) + 3 + 2 * MAX_PROOFS
        println!("OUTPUT IS {:?}", output.unwrap()[0][0..60].to_vec());
    }
}

pub fn mock_test_from_path(path: String, should_fail: bool) {
    let input = parse_input_from_path(path);
    mock_test(input, should_fail);
}

pub fn mock_with_output<P: JsonRpcClient + Clone, S: AxiomCircuitScaffold<P, Fr>>(
    provider: Provider<P>,
    raw_circuit_params: AxiomCircuitParams,
    inputs: Option<S::InputValue>,
) -> Option<Vec<Vec<Fr>>> {
    let circuit_params: BaseCircuitParams = BaseCircuitParams {
        k: 14,
        num_advice_per_phase: vec![4],
        num_lookup_advice_per_phase: vec![1],
        num_fixed: 1,
        num_instance_columns: 1,
        lookup_bits: Some(13),
    };
    let k = circuit_params.k;
    let mut runner = AxiomCircuit::<_, _, S>::new(provider, raw_circuit_params).use_inputs(inputs);

    let instances = runner.instances();

    let prover = MockProver::run(k as u32, &runner, instances).unwrap();
    match prover.verify() {
        Ok(_) => Some(runner.instances()),
        Err(_) => None,
    }
}
