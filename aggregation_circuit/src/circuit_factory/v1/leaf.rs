use anyhow::{bail, Result};
use axiom_eth::{
    halo2_base::gates::circuit::CircuitBuilderStage,
    halo2_proofs::poly::kzg::commitment::ParamsKZG,
    halo2curves::bn256::{Bn256, Fr},
};
use serde::{Deserialize, Serialize};

use crate::{
    keygen::node_params::PinningLeaf,
    prover::prover::ProofRequest,
    types::{ClaimNative, VkNative, WorldcoinInput},
};

use crate::circuits::v1::leaf::*;

/// Request for proofs [start, end).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct WorldcoinRequestLeaf {
    pub start: u32,
    pub end: u32,
    pub depth: usize,
    pub vk: VkNative,
    pub root: String,
    pub grant_id: String,
    pub claims: Vec<ClaimNative>,
}

impl From<WorldcoinRequestLeaf> for WorldcoinInput<Fr> {
    fn from(input: WorldcoinRequestLeaf) -> Self {
        let WorldcoinRequestLeaf {
            vk,
            root,
            grant_id,
            start,
            end,
            depth,
            claims,
        } = input;
        let vk_str = serde_json::to_string(&vk).unwrap();
        WorldcoinInput::new(vk_str, root, grant_id, start, end, depth, claims)
    }
}

impl ProofRequest for WorldcoinRequestLeaf {
    type Circuit = WorldcoinLeafCircuit<Fr>;
    type Pinning = PinningLeaf;
    fn get_k(pinning: &Self::Pinning) -> u32 {
        pinning.params.k() as u32
    }

    fn proof_id(&self) -> String {
        format!(
            "worldcoin_{}_{:06x}_{:06x}_{}_leaf",
            self.hash(),
            self.start,
            self.end,
            self.depth
        )
    }

    fn build(
        self,
        stage: CircuitBuilderStage,
        pinning: Self::Pinning,
        _: Option<&ParamsKZG<Bn256>>,
    ) -> Result<Self::Circuit> {
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

        let input = self.into();
        let circuit = WorldcoinLeafCircuit::new_impl(stage, input, pinning.params, 0);
        if stage.witness_gen_only() {
            circuit.set_break_points(pinning.break_points);
        }
        Ok(circuit)
    }
}
