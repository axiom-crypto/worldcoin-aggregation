use anyhow::{anyhow, Result};
use axiom_core::axiom_eth::{
    halo2_base::gates::circuit::CircuitBuilderStage,
    halo2_proofs::poly::kzg::commitment::ParamsKZG,
    halo2curves::bn256::Bn256,
    snark_verifier_sdk::{halo2::aggregation::AggregationCircuit, Snark},
};

use crate::circuits::v1::intermediate::WorldcoinIntermediateAggregationInput;
use crate::{keygen::node_params::PinningIntermediate, prover::ProofRequest};

/// Request for proofs [start, end).
#[derive(Clone, Debug)]
pub struct WorldcoinRequestIntermediate {
    pub start: u32,
    pub end: u32,
    pub depth: usize,
    pub initial_depth: usize,
    pub snarks: Vec<Snark>,
}

impl ProofRequest for WorldcoinRequestIntermediate {
    type Circuit = AggregationCircuit;
    type Pinning = PinningIntermediate;
    fn get_k(pinning: &Self::Pinning) -> u32 {
        pinning.params.degree
    }
    /// Legacy filename convention
    fn proof_id(&self) -> String {
        format!(
            "worldcoin_{:06x}_{:06x}_{}_{}_inter",
            self.start, self.end, self.depth, self.initial_depth
        )
    }
    fn build(
        self,
        stage: CircuitBuilderStage,
        pinning: Self::Pinning,
        kzg_params: Option<&ParamsKZG<Bn256>>,
    ) -> Result<Self::Circuit> {
        let kzg_params = kzg_params.ok_or_else(|| anyhow!("kzg_params not provided"))?;
        let num_proofs = self.end - self.start;
        let input = WorldcoinIntermediateAggregationInput::new(
            self.snarks,
            num_proofs,
            self.depth,
            self.initial_depth,
        );
        let mut circuit = input.build(stage, pinning.params, kzg_params)?.0;
        if stage.witness_gen_only() {
            circuit.set_break_points(pinning.break_points);
        }
        Ok(circuit)
    }
}
