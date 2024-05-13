use axiom_sdk::cli::{run_cli_on_scaffold, types::AxiomCircuitRunnerOptions, Parser};

pub mod circuit;
pub mod constants;
pub mod mock_test;
pub mod types;

use crate::circuit::WorldcoinCircuit;
use crate::types::WorldcoinNativeInput;

pub fn main() {
    let cli = AxiomCircuitRunnerOptions::parse();

    run_cli_on_scaffold::<WorldcoinCircuit, WorldcoinNativeInput>(cli);
}
