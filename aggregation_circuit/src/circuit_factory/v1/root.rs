use anyhow::{anyhow, Result};
use axiom_core::axiom_eth::{
    halo2_base::gates::circuit::CircuitBuilderStage,
    halo2_proofs::poly::kzg::commitment::ParamsKZG, halo2curves::bn256::Bn256,
    snark_verifier_sdk::Snark,
};
use axiom_eth::snark_verifier_sdk::halo2::aggregation::AggregationCircuit;
use serde::{Deserialize, Serialize};

use crate::{
    circuits::v1::root::WorldcoinRootAggregationInput, keygen::node_params::PinningRoot,
    prover::prover::ProofRequest,
};

use serde_with::{base64::Base64, serde_as, DeserializeAs, SerializeAs};
use axiom_eth::utils::snark_verifier::Base64Bytes;

/// Request for block numbers [start, end).
#[serde_as]
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct WorldcoinRequestRoot {
    pub start: u32,
    pub end: u32,
    pub depth: usize,
    pub initial_depth: usize,
    #[serde_as(as = "Vec<Base64Bytes>")]
    pub snarks: Vec<Snark>,
}

impl ProofRequest for WorldcoinRequestRoot {
    type Circuit = AggregationCircuit;
    type Pinning = PinningRoot;
    fn get_k(pinning: &Self::Pinning) -> u32 {
        pinning.params.degree
    }

    fn proof_id(&self) -> String {
        format!(
            "worldcoin_{:06x}_{:06x}_{}_{}_root",
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
        let input = WorldcoinRootAggregationInput::new(
            self.snarks,
            num_proofs,
            self.depth,
            self.initial_depth,
            kzg_params,
        )?;

        let mut circuit = input.build(stage, pinning.params, kzg_params)?.0;

        if stage.witness_gen_only() {
            circuit.set_break_points(pinning.break_points);
        }
        Ok(circuit)
    }
}
