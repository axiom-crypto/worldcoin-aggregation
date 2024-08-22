//! Intermediate aggregation circuits that aggregate in a binary tree topology:
//! The leaves of the tree are formed by [WorldcoinLeafCircuitV2]s, and intermediate notes
//! of the tree are formed by [WorldcoinIntermediateAggreagtionCircuitV2]s.
//!
//! An [WorldcoinIntermediateAggregationCircuitV2] can aggregate either:
//! - two [WorldcoinLeafCircuitV2]s or
//! - two [WorldcoinIntermediateAggreagtionCircuitV2]s.
//!
//! The root of the aggregation tree will be a [WorldcoinRootAggregationCircuitV2].
//! Intermediate and Root aggregation circuits have different public outputs.
//! Intermediate Aggregation circuit public outputs: [start, end, vk_hash_hi, vk_hash_lo, grant_id, root, claim_root_hi, claim_root_lo]
//! Root Aggregation circuit public outputs: [output_hash_hi, output_hash_lo], where output is
//! [vk_hash_hi, vk_hash_lo, grant_id, root, num_proofs, claim_root_hi, claim_root_lo]
use anyhow::{bail, Ok, Result};
use axiom_eth::{
    halo2_base::{
        gates::{GateInstructions, RangeChip, RangeInstructions},
        AssignedValue, Context,
    },
    halo2_proofs::{
        halo2curves::bn256::{Bn256, Fr},
        poly::{commitment::ParamsProver, kzg::commitment::ParamsKZG},
    },
    keccak::KeccakChip,
    mpt::MPTChip,
    rlc::circuit::builder::RlcCircuitBuilder,
    snark_verifier_sdk::{
        halo2::aggregation::{aggregate_snarks, SnarkAggregationOutput, Svk, VerifierUniversality},
        Snark, SHPLONK,
    },
    utils::{
        build_utils::aggregation::CircuitMetadata,
        eth_circuit::EthCircuitInstructions,
        hilo::HiLo,
        keccak::decorator::RlcKeccakCircuitImpl,
        snark_verifier::{get_accumulator_indices, NUM_FE_ACCUMULATOR},
    },
    Field,
};
use itertools::Itertools;

use crate::{
    circuits::v1::intermediate::WorldcoinIntermediateAggregationInput,
    constants::DUMMY_CLAIM_ROOTS, utils::compute_keccak_for_branch_nodes,
};

pub type WorldcoinIntermediateAggregationCircuitV2 =
    RlcKeccakCircuitImpl<Fr, WorldcoinIntermediateAggregationInputV2>;

#[derive(Clone, Debug)]
pub struct WorldcoinIntermediateAggregationInputV2 {
    pub num_proofs: u32,
    pub snarks: Vec<Snark>,
    pub max_depth: usize,
    pub initial_depth: usize,
    pub svk: Svk,
    pub prev_acc_indices: Vec<Vec<usize>>,
}

impl WorldcoinIntermediateAggregationInputV2 {
    pub fn new(
        snarks: Vec<Snark>,
        num_proofs: u32,
        max_depth: usize,
        initial_depth: usize,
        kzg_params: &ParamsKZG<Bn256>,
    ) -> Result<Self> {
        let svk = kzg_params.get_g()[0].into();
        let prev_acc_indices = get_accumulator_indices(&snarks);
        if max_depth == initial_depth + 1
            && prev_acc_indices.iter().any(|indices| !indices.is_empty())
        {
            bail!("Snarks to be aggregated must not have accumulators: they should come from WorldcoinLeafCircuitV2");
        }
        if max_depth > initial_depth + 1
            && prev_acc_indices
                .iter()
                .any(|indices| indices.len() != NUM_FE_ACCUMULATOR)
        {
            bail!("Snarks to be aggregated must all be WorldcoinIntermediateAggregationCircuitV2");
        }

        Ok(Self {
            num_proofs,
            snarks,
            max_depth,
            initial_depth,
            svk,
            prev_acc_indices,
        })
    }

    pub fn virtual_assign_phase0_helper(
        &self,
        builder: &mut RlcCircuitBuilder<Fr>,
        mpt: &MPTChip<Fr>,
        expose_num_proofs: bool,
    ) -> () {
        let keccak = mpt.keccak();
        let range = keccak.range();
        let pool = builder.base.pool(0);
        let SnarkAggregationOutput {
            mut previous_instances,
            accumulator,
            ..
        } = aggregate_snarks::<SHPLONK>(
            pool,
            range,
            self.svk,
            self.snarks.clone(),
            VerifierUniversality::None,
        );

        // remove old accumulators
        for (prev_instance, acc_indices) in
            previous_instances.iter_mut().zip_eq(&self.prev_acc_indices)
        {
            for i in acc_indices.iter().sorted().rev() {
                prev_instance.remove(*i);
            }
        }

        let ctx = pool.main();

        let num_proofs = ctx.load_witness(Fr::from(self.num_proofs as u64));

        let new_instances = Self::join_previous_instances::<Fr>(
            ctx,
            &range,
            &keccak,
            previous_instances.try_into().unwrap(),
            num_proofs,
            self.max_depth,
        );

        let assigned_instances: &mut Vec<AssignedValue<Fr>> =
            &mut builder.base.assigned_instances[0];

        assigned_instances.extend(accumulator);

        if expose_num_proofs {
            // root circuit
            // [vk_hash_hi, vk_hash_lo, root, num_proofs, claim_root_hi, claim_root_lo]
            assigned_instances.extend_from_slice(&new_instances[2..5]);
            assigned_instances.push(num_proofs);
            assigned_instances.extend_from_slice(&new_instances[5..7]);
            assert_eq!(assigned_instances.len(), NUM_FE_ACCUMULATOR + 6);
        } else {
            // intermediate circuit
            // [start, end, vk_hash_hi, vk_hash_lo, root, claim_root_hi, claim_root_lo]
            assigned_instances.extend_from_slice(&new_instances[0..7]);
            assert_eq!(assigned_instances.len(), NUM_FE_ACCUMULATOR + 7);
        }
    }

    /// Takes the concatenated previous instances from two `WorldcoinIntermediateAggregationCircuitV2`s
    /// of max depth `max_depth - 1` and
    /// - checks that they form a chain of `max_depth`
    ///
    /// If `max_depth - 1 == initial_depth`, then the previous instances are from two `WorldcoinLeafCircuitV2`s.
    ///
    /// Returns the new instances for the depth `max_depth` circuit (without accumulators)
    ///
    /// ## Assumptions
    /// - `prev_instances` are the previous instances **with old accumulators removed**.
    /// /// Data passed from phase0 to phase1
    /// instances:
    /// [0] start
    /// [1] end
    /// [2, 3] vkey_hash
    /// [4] root
    /// [5, 6] claim_root
    pub fn join_previous_instances<F: Field>(
        ctx: &mut Context<F>,
        range: &RangeChip<F>,
        keccak: &KeccakChip<F>,
        prev_instances: [Vec<AssignedValue<F>>; 2],
        num_proofs: AssignedValue<F>,
        max_depth: usize,
    ) -> Vec<AssignedValue<F>> {
        let num_instance_prev_depth = Self::get_num_instance();
        let (mut instances, is_2nd_shard_dummy) =
            WorldcoinIntermediateAggregationInput::check_and_join_shared_instances(
                ctx,
                range,
                &prev_instances,
                num_proofs,
                max_depth,
                num_instance_prev_depth,
            );

        let [instances0, instances1] = prev_instances;

        // generate claim root
        // if the 2nd snark is not dummy, we simply calculate keccak(claim_root_left| claim_root_right)
        // if the 2nd snark is dummy, we need to calculate the right child at (max_depth - 1) with keccak256(abi.encodePacked(address(0), bytes32(0))) as leaves
        // since this is aggregation layer, max_depth - 1 >= 0
        let dummy_claim_root = DUMMY_CLAIM_ROOTS[max_depth - 1];
        let dummy_claim_root_hi = F::from_u128(u128::from_be_bytes(
            dummy_claim_root[..16].try_into().unwrap(),
        ));

        let dummy_claim_root_lo = F::from_u128(u128::from_be_bytes(
            dummy_claim_root[16..].try_into().unwrap(),
        ));
        let dummy_claim_root_hi = ctx.load_constant(dummy_claim_root_hi);
        let dummy_claim_root_lo = ctx.load_constant(dummy_claim_root_lo);

        let claim_root_left = HiLo::from_hi_lo([instances0[5], instances0[6]]);
        let mut claim_root_right = HiLo::from_hi_lo([instances1[5], instances1[6]]);

        let claim_root_right_hi = range.gate().select(
            ctx,
            dummy_claim_root_hi,
            claim_root_right.hi(),
            is_2nd_shard_dummy,
        );
        let claim_root_right_lo = range.gate().select(
            ctx,
            dummy_claim_root_lo,
            claim_root_right.lo(),
            is_2nd_shard_dummy,
        );

        claim_root_right = HiLo::from_hi_lo([claim_root_right_hi, claim_root_right_lo]);

        // keccak(claim_root_left| claim_root_right)
        let claim_root = compute_keccak_for_branch_nodes(
            ctx,
            range,
            keccak,
            &claim_root_left,
            &claim_root_right,
        );

        // new instances for the aggregation layer
        // [start, end, vk_hash_hi, vk_hash_lo, grant_id, root, claim_root_hi, claim_root_lo]
        instances.extend(claim_root.hi_lo());

        instances
    }

    // num_instance excluding the accumulator, it's the same number as leaf circuit num_instance
    pub fn get_num_instance() -> usize {
        7
    }
}

impl EthCircuitInstructions<Fr> for WorldcoinIntermediateAggregationInputV2 {
    type FirstPhasePayload = ();

    fn virtual_assign_phase0(
        &self,
        builder: &mut RlcCircuitBuilder<Fr>,
        mpt: &MPTChip<Fr>,
    ) -> Self::FirstPhasePayload {
        self.virtual_assign_phase0_helper(builder, mpt, false)
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

// required by RlcKeccakCircuitImpl
impl CircuitMetadata for WorldcoinIntermediateAggregationInputV2 {
    const HAS_ACCUMULATOR: bool = true;

    fn num_instance(&self) -> Vec<usize> {
        vec![NUM_FE_ACCUMULATOR + 7]
    }
}
