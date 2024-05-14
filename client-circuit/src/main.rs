use axiom_sdk::cli::{run_cli_on_scaffold, types::AxiomCircuitRunnerOptions, Parser};

use client_circuit::circuit::WorldcoinCircuit;
use client_circuit::types::WorldcoinNativeInput;

pub fn main() {
    let cli = AxiomCircuitRunnerOptions::parse();

    run_cli_on_scaffold::<WorldcoinCircuit, WorldcoinNativeInput>(cli);
}
