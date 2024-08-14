use anyhow::{anyhow, bail, Result};
use axiom_eth::{
    halo2_base::gates::circuit::CircuitBuilderStage,
    halo2_proofs::poly::kzg::commitment::ParamsKZG, halo2curves::bn256::Bn256,
    snark_verifier_sdk::Snark,
};

use serde::{Deserialize, Serialize};

use crate::{
    circuits::v1::root::{WorldcoinRootAggregationCircuit, WorldcoinRootAggregationInput},
    keygen::node_params::PinningRoot,
    prover::prover::ProofRequest,
};

use axiom_eth::utils::snark_verifier::Base64Bytes;
use serde_with::serde_as;

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
    type Circuit = WorldcoinRootAggregationCircuit;
    type Pinning = PinningRoot;
    fn get_k(pinning: &Self::Pinning) -> u32 {
        pinning.params.k() as u32
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

        if self.end < self.start {
            bail!("Invalid index range: [{}, {}]", self.start, self.end);
        }
        let num_proofs = self.end - self.start;
        if num_proofs > (1 << self.depth) {
            bail!(
                "Number of proofs {} is too large for depth {}",
                num_proofs,
                self.depth
            );
        }

        let input = WorldcoinRootAggregationInput::new(
            self.snarks,
            num_proofs,
            self.depth,
            self.initial_depth,
            kzg_params,
        )?;

        let circuit = WorldcoinRootAggregationCircuit::new_impl(stage, input, pinning.params, 0);
        if stage.witness_gen_only() {
            circuit.set_break_points(pinning.break_points);
        }
        Ok(circuit)
    }
}
