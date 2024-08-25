use anyhow::{anyhow, Result};
use axiom_eth::{
    halo2_base::gates::circuit::CircuitBuilderStage,
    halo2_proofs::poly::kzg::commitment::ParamsKZG,
    halo2curves::bn256::Bn256,
    snark_verifier_sdk::{halo2::aggregation::AggregationCircuit, Snark},
    utils::{merkle_aggregation::InputMerkleAggregation, snark_verifier::EnhancedSnark},
};
use serde::{Deserialize, Serialize};

use crate::{keygen::node_params::PinningEvm, prover::ProofRequest};

use serde_with::serde_as;

use axiom_eth::utils::snark_verifier::Base64Bytes;

#[serde_as]
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct WorldcoinRequestLeafAgg {
    pub start: u32,
    pub end: u32,
    pub depth: usize,
    pub initial_depth: usize,

    #[serde_as(as = "Base64Bytes")]
    pub snark: Snark,
}

impl ProofRequest for WorldcoinRequestLeafAgg {
    type Circuit = AggregationCircuit;
    type Pinning = PinningEvm;
    fn get_k(pinning: &Self::Pinning) -> u32 {
        pinning.params.agg_params.degree
    }
    /// Legacy filename convention
    fn proof_id(&self) -> String {
        format!(
            "worldcoin_{}_{:06x}_{:06x}_{}_{}_agg",
            self.hash(),
            self.start,
            self.end,
            self.depth,
            self.initial_depth,
        )
    }
    fn build(
        self,
        stage: CircuitBuilderStage,
        pinning: Self::Pinning,
        kzg_params: Option<&ParamsKZG<Bn256>>,
    ) -> Result<Self::Circuit> {
        let kzg_params = kzg_params.ok_or_else(|| anyhow!("kzg_params not provided"))?;
        let input = InputMerkleAggregation::new([EnhancedSnark::new(self.snark, None)]);
        let mut circuit = input.build(stage, pinning.params.agg_params, kzg_params)?;
        if stage.witness_gen_only() {
            circuit.set_break_points(pinning.break_points);
        }
        Ok(circuit)
    }
}
