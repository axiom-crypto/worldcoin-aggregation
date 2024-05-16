use axiom_sdk::cli::{run_cli_on_scaffold, types::AxiomCircuitRunnerOptions, Parser};
use std::fmt::Debug;

use client_circuit::circuit::WorldcoinCircuit;
use client_circuit::types::WorldcoinNativeInput;

pub fn main() {
    env_logger::init();
    let cli = AxiomCircuitRunnerOptions::parse();

    run_cli_on_scaffold::<WorldcoinCircuit, WorldcoinNativeInput>(cli);
}
