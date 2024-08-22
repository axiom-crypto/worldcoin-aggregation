use anyhow::{anyhow, Result};
use axiom_eth::{
    halo2_base::gates::circuit::CircuitBuilderStage,
    halo2_proofs::poly::kzg::commitment::ParamsKZG,
    halo2curves::bn256::Bn256,
    snark_verifier_sdk::{halo2::aggregation::AggregationCircuit, Snark},
};
use serde::{Deserialize, Serialize};

use crate::WorldcoinIntermediateAggregationInput;
use crate::{keygen::node_params::PinningIntermediate, prover::ProofRequest};

use axiom_eth::utils::snark_verifier::Base64Bytes;
use serde_with::serde_as;

/// Request for proofs [start, end).
#[serde_as]
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct WorldcoinRequestIntermediate {
    pub start: u32,
    pub end: u32,
    pub depth: usize,
    pub initial_depth: usize,
    #[serde_as(as = "Vec<Base64Bytes>")]
    pub snarks: Vec<Snark>,
}

impl ProofRequest for WorldcoinRequestIntermediate {
    #[cfg(feature = "v1")]
    type Circuit = AggregationCircuit;
    #[cfg(feature = "v1")]
    type Pinning = PinningIntermediate;

    #[cfg(feature = "v2")]
    type Circuit = WorldcoinIntermediateAggregationCircuit;
    #[cfg(feature = "v2")]
    type Pinning = PinningIntermediateV2;

    fn get_k(pinning: &Self::Pinning) -> u32 {
        #[cfg(feature = "v1")]
        return pinning.params.degree;

        #[cfg(feature = "v2")]
        return pinning.params.k() as u32;
    }
    /// Legacy filename convention
    fn proof_id(&self) -> String {
        format!(
            "worldcoin_{}_{:06x}_{:06x}_{}_{}_inter",
            self.hash(),
            self.start,
            self.end,
            self.depth,
            self.initial_depth
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

        #[cfg(feature = "v1")]
        {
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

        #[cfg(feature = "v2")]
        {
            let input = WorldcoinIntermediateAggregationInput::new(
                self.snarks,
                num_proofs,
                self.depth,
                self.initial_depth,
                kzg_params,
            )?;

            let circuit =
                WorldcoinIntermediateAggregationCircuit::new_impl(stage, input, pinning.params, 0);
            if stage.witness_gen_only() {
                circuit.set_break_points(pinning.break_points);
            }
            Ok(circuit)
        }
    }
}
