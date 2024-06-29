use axiom_sdk::cli::{run_cli_on_scaffold, types::AxiomCircuitRunnerOptions, Parser};

use client_circuit::circuit_v2::WorldcoinV2Circuit;
use client_circuit::types::WorldcoinNativeInput;

pub fn main() {
    env_logger::init();
    let mut cli = AxiomCircuitRunnerOptions::parse();
    cli.provider = Some("http://dummyProvider".to_string());
    run_cli_on_scaffold::<WorldcoinV2Circuit, WorldcoinNativeInput>(cli);
}
