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
        gates::{circuit::CircuitBuilderStage, GateInstructions, RangeChip, RangeInstructions},
        AssignedValue, Context,
        QuantumCell::Constant,
    },
    halo2_proofs::{
        halo2curves::bn256::{Bn256, Fr},
        poly::{commitment::ParamsProver, kzg::commitment::ParamsKZG},
    },
    keccak::KeccakChip,
    mpt::MPTChip,
    rlc::circuit::builder::RlcCircuitBuilder,
    snark_verifier_sdk::{
        halo2::aggregation::{
            aggregate_snarks, AggregationCircuit, SnarkAggregationOutput, Svk, VerifierUniversality,
        },
        Snark, SHPLONK,
    },
    utils::{
        build_utils::aggregation::CircuitMetadata,
        eth_circuit::EthCircuitInstructions,
        hilo::HiLo,
        keccak::decorator::RlcKeccakCircuitImpl,
        snark_verifier::{get_accumulator_indices, AggregationCircuitParams, NUM_FE_ACCUMULATOR},
        uint_to_bytes_be,
    },
    Field,
};
use itertools::Itertools;

use crate::utils::compute_keccak_for_branch_nodes;

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

        let new_instances = join_previous_instances::<Fr>(
            ctx,
            &range,
            &keccak,
            previous_instances.try_into().unwrap(),
            num_proofs,
            self.max_depth,
            self.initial_depth,
        );

        let assigned_instances: &mut Vec<AssignedValue<Fr>> =
            &mut builder.base.assigned_instances[0];

        assigned_instances.extend(accumulator);

        if expose_num_proofs {
            // root circuit
            // [vk_hash_hi, vk_hash_lo, grant_id, root, num_proofs, claim_root_hi, claim_root_lo]
            assigned_instances.extend_from_slice(&new_instances[2..6]);
            assigned_instances.push(num_proofs);
            assigned_instances.extend_from_slice(&new_instances[6..8]);
            assert_eq!(assigned_instances.len(), NUM_FE_ACCUMULATOR + 7);
        } else {
            // intermediate circuit
            // [start, end, vk_hash_hi, vk_hash_lo, grant_id, root, claim_root_hi, claim_root_lo]
            assigned_instances.extend_from_slice(&new_instances[0..8]);
            assert_eq!(assigned_instances.len(), NUM_FE_ACCUMULATOR + 8);
        }
    }

    // num_instance excluding the accumulator, it's the same number as leaf circuit num_instance
    pub fn get_num_instance() -> usize {
        8
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

impl CircuitMetadata for WorldcoinIntermediateAggregationInputV2 {
    const HAS_ACCUMULATOR: bool = true;

    fn num_instance(&self) -> Vec<usize> {
        vec![NUM_FE_ACCUMULATOR + 8]
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
/// [4] grant_id
/// [5] root
/// [6, 7] claim_root
pub fn join_previous_instances<F: Field>(
    ctx: &mut Context<F>,
    range: &RangeChip<F>,
    keccak: &KeccakChip<F>,
    prev_instances: [Vec<AssignedValue<F>>; 2],
    num_proofs: AssignedValue<F>,
    max_depth: usize,
    initial_depth: usize,
) -> Vec<AssignedValue<F>> {
    let prev_depth = max_depth - 1;
    let num_instance_prev_depth = WorldcoinIntermediateAggregationInputV2::get_num_instance();
    assert_eq!(num_instance_prev_depth, prev_instances[0].len());
    assert_eq!(num_instance_prev_depth, prev_instances[1].len());

    let [instance0, instance1] = prev_instances;

    // join & sanitize index
    let (start_idx, intermed_idx0) = (instance0[0], instance0[1]);
    let (intermed_idx1, mut end_idx) = (instance1[0], instance1[1]);
    let num_proofs0 = range.gate().sub(ctx, intermed_idx0, start_idx);
    let num_proofs1 = range.gate().sub(ctx, end_idx, intermed_idx1);

    let prev_max_proofs_plus_one = (1 << prev_depth) + 1;
    range.check_less_than_safe(ctx, num_proofs0, prev_max_proofs_plus_one);
    range.check_less_than_safe(ctx, num_proofs1, prev_max_proofs_plus_one);

    // indicator of whether the 2nd shard is a dummy shard
    let is_2nd_shard_dummy = range.is_less_than_safe(ctx, num_proofs, prev_max_proofs_plus_one);

    // if the 2nd shard is dummy, the end index for the aggregation should be the end index of the
    // first shard
    end_idx = range
        .gate()
        .select(ctx, intermed_idx0, end_idx, is_2nd_shard_dummy);

    // make sure shards link up
    let mut eq_check = range.gate().is_equal(ctx, intermed_idx0, intermed_idx1);
    eq_check = range.gate().or(ctx, eq_check, is_2nd_shard_dummy);

    range.gate().assert_is_const(ctx, &eq_check, &F::ONE);

    // if num_proofs > 2^prev_depth, then num_proofs0 must equal 2^prev_depth
    let prev_max_proofs = range.gate().pow_of_two()[prev_depth];
    let is_max_depth0 = range
        .gate()
        .is_equal(ctx, num_proofs0, Constant(prev_max_proofs));
    eq_check = range.gate().or(ctx, is_max_depth0, is_2nd_shard_dummy);
    range.gate().assert_is_const(ctx, &eq_check, &F::ONE);

    // check num_proofs is correct
    let boundary_num_diff = range.gate().sub(ctx, end_idx, start_idx);

    ctx.constrain_equal(&boundary_num_diff, &num_proofs);

    let num_instance = WorldcoinIntermediateAggregationInputV2::get_num_instance();

    let mut instances = Vec::with_capacity(num_instance);

    // constrain vkeyHash, grant_id, root to be equal for the deps
    // which is idx 2..6
    for _i in 2..6 {
        ctx.constrain_equal(&instance0[_i], &instance1[_i]);
    }

    // generate claim root
    // if the 2nd snark is not dummy, we simply calculate keccak(claim_root_left| claim_root_right)
    // if the 2nd snark is dummy, we need to calculate the right child at (max_depth - 1) with keccak256(abi.encodePacked(address(0), bytes32(0))) as leaves
    // since this is aggregation layer, max_depth - 1 >= 0
    let dummy_claim_root = calculate_dummy_merkle_root_at_depth(ctx, range, keccak, max_depth - 1);

    let claim_root_left = HiLo::from_hi_lo([instance0[6], instance0[7]]);
    let mut claim_root_right = HiLo::from_hi_lo([instance1[6], instance1[7]]);

    let claim_root_right_hi = range.gate().select(
        ctx,
        dummy_claim_root.hi(),
        claim_root_right.hi(),
        is_2nd_shard_dummy,
    );
    let claim_root_right_lo = range.gate().select(
        ctx,
        dummy_claim_root.lo(),
        claim_root_right.lo(),
        is_2nd_shard_dummy,
    );

    claim_root_right = HiLo::from_hi_lo([claim_root_right_hi, claim_root_right_lo]);

    // keccak(claim_root_left| claim_root_right)
    let claim_root =
        compute_keccak_for_branch_nodes(ctx, range, keccak, &claim_root_left, &claim_root_right);

    // new instances for the aggregation layer
    // [start, end, vk_hash_hi, vk_hash_lo, grant_id, root, claim_root_hi, claim_root_lo]
    instances.push(start_idx);
    instances.push(end_idx);
    instances.extend_from_slice(&instance0[2..6]);
    instances.extend(claim_root.hi_lo());

    instances
}

pub fn calculate_dummy_merkle_root_at_depth<F: Field>(
    ctx: &mut Context<F>,
    range: &RangeChip<F>,
    keccak: &KeccakChip<F>,
    depth: usize,
) -> HiLo<AssignedValue<F>> {
    let zero = ctx.load_zero();
    // 20 bytes for address + 32 bytes for bytes32
    let mut bytes = uint_to_bytes_be(ctx, range, &zero, 20);
    bytes.extend(uint_to_bytes_be(ctx, range, &zero, 32));
    let bytes: Vec<AssignedValue<F>> = bytes.iter().map(|sb| *sb.as_ref()).collect();
    let keccak_hash = keccak.keccak_fixed_len(ctx, bytes);
    //  keccak256(abi.encodePacked(address(0), bytes32(0)))
    let mut keccak_hash = HiLo::from_hi_lo([keccak_hash.output_hi, keccak_hash.output_lo]);
    for _i in 0..depth {
        keccak_hash =
            compute_keccak_for_branch_nodes(ctx, range, keccak, &keccak_hash, &keccak_hash)
    }
    keccak_hash
}
