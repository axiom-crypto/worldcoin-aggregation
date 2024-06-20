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
use ethers::prelude::Http;
use ethers::providers::{JsonRpcClient, Provider};
use halo2curves::bn256::Fr;

use crate::{
    circuit_v1::WorldcoinV1Circuit,
    circuit_v2::WorldcoinV2Circuit,
    types::{WorldcoinInput, WorldcoinInputCoreParams, WorldcoinNativeInput},
};

pub fn parse_input_from_path(path: String) -> WorldcoinInput<Fr> {
    let worldcoin_input: WorldcoinNativeInput =
        serde_json::from_reader(File::open(path.clone()).expect("path does not exist")).unwrap();
    worldcoin_input.into()
}

pub fn mock_test(input: WorldcoinInput<Fr>, should_fail: bool, version: &str) -> Option<Vec<Fr>> {
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
    let client = Provider::<Http>::try_from("http://dummy").unwrap();

    let output = if version == "v1" {
        mock_with_output::<_, WorldcoinV1Circuit>(
            client,
            AxiomCircuitParams::Keccak(params),
            Some(input),
            WorldcoinInputCoreParams { max_proofs: 16 },
        )
    } else {
        mock_with_output::<_, WorldcoinV2Circuit>(
            client,
            AxiomCircuitParams::Keccak(params),
            Some(input),
            WorldcoinInputCoreParams { max_proofs: 16 },
        )
    };
    assert_eq!((output == None), should_fail);

    let output_size = if version == "v1" { 72 } else { 8 };
    match output {
        Some(value) => Some(value[0][0..output_size].to_vec()),
        None => None,
    }
}

pub fn mock_test_from_path(path: String, should_fail: bool, version: &str) -> Option<Vec<Fr>> {
    let input = parse_input_from_path(path);
    mock_test(input, should_fail, version)
}

pub fn mock_with_output<P: JsonRpcClient + Clone, S: AxiomCircuitScaffold<P, Fr>>(
    provider: Provider<P>,
    raw_circuit_params: AxiomCircuitParams,
    inputs: Option<S::InputValue>,
    params: S::CoreParams,
) -> Option<Vec<Vec<Fr>>> {
    let mut runner = AxiomCircuit::<_, _, S>::new(provider, raw_circuit_params)
        .use_inputs(inputs)
        .use_core_params(params);
    let instances = runner.instances();

    runner.calculate_params();

    let prover = MockProver::run(17 as u32, &runner, instances).unwrap();

    match prover.verify() {
        Ok(_) => Some(runner.instances()),
        Err(_) => None,
    }
}
