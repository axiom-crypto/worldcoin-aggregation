use axiom_sdk::cli::{run_cli_on_scaffold, types::AxiomCircuitRunnerOptions, Parser};

use client_circuit::circuit_v2::WorldcoinV2Circuit;
use client_circuit::types::WorldcoinNativeInput;

pub fn main() {
    env_logger::init();
    let cli = AxiomCircuitRunnerOptions::parse();
    run_cli_on_scaffold::<WorldcoinV2Circuit, WorldcoinNativeInput>(cli);
}
