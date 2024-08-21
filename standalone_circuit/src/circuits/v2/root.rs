//! The root of the aggregation tree.
//! An [WorldcoinRootAggregationCircuit] can aggregate either:
//! - two [WorldcoinLeafnCircuit]s (if `max_depth == initial_depth + 1`) or
//! - two [WorldcoinIntermediateAggregationCircuit]s.
//!
//! The difference between Intermediate and Root aggregation circuits is that they expose different public outputs. Root aggregation
//! exposes the hash of the output [vk_hash_hi, vk_hash_lo, root, num_proofs, claim_root_hi, claim_root_lo]

use anyhow::Result;
use axiom_eth::{
    halo2_proofs::poly::kzg::commitment::ParamsKZG,
    halo2curves::bn256::{Bn256, Fr},
    mpt::MPTChip,
    rlc::circuit::builder::RlcCircuitBuilder,
    snark_verifier_sdk::Snark,
    utils::{
        build_utils::aggregation::CircuitMetadata, eth_circuit::EthCircuitInstructions,
        keccak::decorator::RlcKeccakCircuitImpl, snark_verifier::NUM_FE_ACCUMULATOR,
    },
};

use super::intermediate::WorldcoinIntermediateAggregationInputV2;

pub type WorldcoinRootAggregationCircuitV2 =
    RlcKeccakCircuitImpl<Fr, WorldcoinRootAggregationInputV2>;

#[derive(Clone, Debug)]
pub struct WorldcoinRootAggregationInputV2(WorldcoinIntermediateAggregationInputV2);

impl WorldcoinRootAggregationInputV2 {
    pub fn new(
        snarks: Vec<Snark>,
        num_proofs: u32,
        max_depth: usize,
        initial_depth: usize,
        kzg_params: &ParamsKZG<Bn256>,
    ) -> Result<Self> {
        WorldcoinIntermediateAggregationInputV2::new(
            snarks,
            num_proofs,
            max_depth,
            initial_depth,
            kzg_params,
        )
        .map(Self)
    }
}

impl EthCircuitInstructions<Fr> for WorldcoinRootAggregationInputV2 {
    type FirstPhasePayload = ();

    fn virtual_assign_phase0(
        &self,
        builder: &mut RlcCircuitBuilder<Fr>,
        mpt: &MPTChip<Fr>,
    ) -> Self::FirstPhasePayload {
        self.0.virtual_assign_phase0_helper(builder, mpt, true)
    }

    fn virtual_assign_phase1(
        &self,
        _: &mut RlcCircuitBuilder<Fr>,
        _: &MPTChip<Fr>,
        _: Self::FirstPhasePayload,
    ) {
        // do nothing
    }
}

impl CircuitMetadata for WorldcoinRootAggregationInputV2 {
    const HAS_ACCUMULATOR: bool = true;

    fn num_instance(&self) -> Vec<usize> {
        vec![NUM_FE_ACCUMULATOR + 6]
    }
}
