use axiom_sdk::cli::{run_cli_on_scaffold, types::AxiomCircuitRunnerOptions, Parser};

use client_circuit::types::WorldcoinNativeInput;
use client_circuit::world_id_balance_circuit::WorldIdBalanceCircuit;
use client_circuit::world_id_balance_types::WorldIdBalanceNativeInput;

pub fn main() {
    env_logger::init();
    let cli = AxiomCircuitRunnerOptions::parse();
    run_cli_on_scaffold::<WorldIdBalanceCircuit, WorldIdBalanceNativeInput>(cli);
}
