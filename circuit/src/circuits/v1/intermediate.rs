//! Intermediate aggregation circuits that aggregate in a binary tree topology:
//! The leaves of the tree are formed by [WorldcoinLeafCircuit]s, and intermediate notes
//! of the tree are formed by [WorldcoinIntermediateAggreagtionCircuit]s.
//!
//! An [WorldcoinIntermediateAggregationCircuit] can aggregate either:
//! - two [WorldcoinLeafCircuit]s or
//! - two [WorldcoinIntermediateAggreagtionCircuit]s.
//!
//! The root of the aggregation tree will be a [WorldcoinRootAggregationCircuit].
//! Intermediate and Root aggregation circuits have different public outputs.
//! Intermediate Aggregation circuit public outputs: [start, end, vk_hash_hi, vk_hash_lo, root, ...grant_ids, ...receivers, ...nullifier_hashes]
//! Root Aggregation circuit public outputs: [output_hash_hi, output_hash_lo], where output is
//! [vk_hash_hi, vk_hash_lo, root, num_proofs, ...grant_ids, ...receivers, ...nullifier_hashes]
use anyhow::{bail, Ok, Result};
use axiom_eth::{
    halo2_base::{
        gates::{circuit::CircuitBuilderStage, GateInstructions, RangeChip, RangeInstructions},
        AssignedValue, Context,
        QuantumCell::Constant,
    },
    halo2_proofs::{
        halo2curves::bn256::{Bn256, Fr},
        poly::kzg::commitment::ParamsKZG,
    },
    snark_verifier_sdk::{
        halo2::aggregation::{AggregationCircuit, VerifierUniversality},
        Snark, SHPLONK,
    },
    utils::snark_verifier::{
        get_accumulator_indices, AggregationCircuitParams, NUM_FE_ACCUMULATOR,
    },
    Field,
};
use itertools::Itertools;

pub struct WorldcoinIntermediateAggregationCircuit(pub AggregationCircuit);

/// The input to create an intermediate [AggregationCircuit] that aggregates [WorldcoinLeafCircuit]s.
/// These are intermediate aggregations because they do not perform additional keccaks. Therefore the public instance format (after excluding accumulators) is
/// the same as that of the original [WorldcoinLeafCircuit]s.
#[derive(Clone, Debug)]
pub struct WorldcoinIntermediateAggregationInput {
    // aggregation circuit with `instances` the accumulator (two G1 points) for delayed pairing verification
    pub num_proofs: u32,
    /// `snarks` should be exactly two snarks of either
    /// - `WorldcoinLeafCircuit` if `max_depth == initial_depth + 1` or
    /// - `WorldcoinIntermediateAggregationCircuit` (this circuit) otherwise
    ///
    /// Assumes `num_proofs > 0`.
    pub snarks: Vec<Snark>,
    pub max_depth: usize,
    pub initial_depth: usize,
}

impl WorldcoinIntermediateAggregationInput {
    pub fn new(
        snarks: Vec<Snark>,
        num_proofs: u32,
        max_depth: usize,
        initial_depth: usize,
    ) -> Self {
        assert_ne!(num_proofs, 0);
        assert_eq!(snarks.len(), 2);
        assert!(max_depth > initial_depth);
        assert!(num_proofs <= 1 << max_depth);

        Self {
            snarks,
            num_proofs,
            max_depth,
            initial_depth,
        }
    }

    /// Takes the concatenated previous instances from two `WorldcoinIntermediateAggregationCircuit`s
    /// of max depth `max_depth - 1` and
    /// - checks that they form a chain of `max_depth`
    ///
    /// If `max_depth - 1 == initial_depth`, then the previous instances are from two `WorldcoinLeafCircuit`s.
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
    /// [5, 5 + 1 << max_depth) grant_ids_i
    /// [5 + 1 << max_depth, 5 + 2 * (1 << max_depth)) receivers_i
    /// [5 + 2 * (1 << max_depth), 5 + 3 * (1 << max_depth)) nullifier_hashes_i
    pub fn join_previous_instances<F: Field>(
        ctx: &mut Context<F>,
        range: &RangeChip<F>,
        prev_instances: [Vec<AssignedValue<F>>; 2],
        num_proofs: AssignedValue<F>,
        max_depth: usize,
    ) -> Vec<AssignedValue<F>> {
        let num_instance_prev_depth = Self::get_num_instance(max_depth - 1);
        let (mut instances, _) = Self::check_and_join_shared_instances(
            ctx,
            range,
            &prev_instances,
            num_proofs,
            max_depth,
            num_instance_prev_depth,
        );
        let [instance0, instance1] = prev_instances;

        // combine grant_ids
        let prev_depth = max_depth - 1;
        let max_proofs_prev_depth = 1 << prev_depth;
        instances.extend(&instance0[5..5 + max_proofs_prev_depth]);
        instances.extend(&instance1[5..5 + max_proofs_prev_depth]);

        // combine receivers
        instances.extend(&instance0[5 + max_proofs_prev_depth..5 + 2 * max_proofs_prev_depth]);
        instances.extend(&instance1[5 + max_proofs_prev_depth..5 + 2 * max_proofs_prev_depth]);

        // combine nullifier_hashes
        instances.extend(&instance0[5 + 2 * max_proofs_prev_depth..5 + 3 * max_proofs_prev_depth]);
        instances.extend(&instance1[5 + 2 * max_proofs_prev_depth..5 + 3 * max_proofs_prev_depth]);

        instances
    }

    /// Sanity check against the start & end indexes of two proofs, check instances[2..5] (vk_hash_hi, vk_hash_lo, root) are equal.
    /// Return new start, end indexes for this aggregated proof and a selector indicating whether the 2nd proof is dummy.
    ///
    /// If the the 2nd proof is not dummy, the proofs should link up.
    /// If the 2nd proof is dummy, num_proofs should <= max_proofs_prev_depth
    ///
    /// # Returns a tuple of (new_instances, is_2nd_proof_dummy)
    /// - `new_instances` the first 5 instances (shared by v1/v2 intermediate and root) circuits. [start, end, vk_hash_hi, vk_hash_lo, root]
    /// - `is_2nd_proof_dummy` a selector to indicate whether the 2nd proof is dummy
    pub fn check_and_join_shared_instances<F: Field>(
        ctx: &mut Context<F>,
        range: &RangeChip<F>,
        prev_instances: &[Vec<AssignedValue<F>>; 2],
        num_proofs: AssignedValue<F>,
        max_depth: usize,
        num_instance_prev_depth: usize,
    ) -> (Vec<AssignedValue<F>>, AssignedValue<F>) {
        let [instances0, instances1] = prev_instances;

        assert_eq!(num_instance_prev_depth, instances0.len());
        assert_eq!(num_instance_prev_depth, instances1.len());

        // join & sanitize index
        let (start_idx, intermed_idx0) = (instances0[0], instances0[1]);
        let (intermed_idx1, mut end_idx) = (instances1[0], instances1[1]);
        let num_proofs0 = range.gate().sub(ctx, intermed_idx0, start_idx);
        let num_proofs1 = range.gate().sub(ctx, end_idx, intermed_idx1);

        let prev_depth = max_depth - 1;
        let prev_max_proofs_plus_one = (1 << prev_depth) + 1;
        range.check_less_than_safe(ctx, num_proofs0, prev_max_proofs_plus_one);
        range.check_less_than_safe(ctx, num_proofs1, prev_max_proofs_plus_one);

        // indicator of whether the 2nd proof is a dummy proof
        let is_2nd_proof_dummy = range.is_less_than_safe(ctx, num_proofs, prev_max_proofs_plus_one);

        // if the 2nd proof is dummy, the end index for the aggregation should be the end index of the
        // first proof
        end_idx = range
            .gate()
            .select(ctx, intermed_idx0, end_idx, is_2nd_proof_dummy);

        // make sure proofs link up
        let mut eq_check = range.gate().is_equal(ctx, intermed_idx0, intermed_idx1);
        eq_check = range.gate().or(ctx, eq_check, is_2nd_proof_dummy);

        range.gate().assert_is_const(ctx, &eq_check, &F::ONE);

        // if num_proofs > 2^prev_depth, then num_proofs0 must equal 2^prev_depth
        let prev_max_proofs = range.gate().pow_of_two()[prev_depth];
        let is_max_depth0 = range
            .gate()
            .is_equal(ctx, num_proofs0, Constant(prev_max_proofs));
        eq_check = range.gate().or(ctx, is_max_depth0, is_2nd_proof_dummy);
        range.gate().assert_is_const(ctx, &eq_check, &F::ONE);

        // check num_proofs is correct
        let boundary_num_diff = range.gate().sub(ctx, end_idx, start_idx);

        ctx.constrain_equal(&boundary_num_diff, &num_proofs);

        // constrain vkeyHash, root to be equal for the deps
        // which is idx 2..5
        for _i in 2..5 {
            ctx.constrain_equal(&instances0[_i], &instances1[_i]);
        }

        let new_instances = [start_idx, end_idx]
            .into_iter()
            .chain(instances0[2..5].iter().cloned())
            .collect();
        (new_instances, is_2nd_proof_dummy)
    }

    pub fn get_num_instance(max_depth: usize) -> usize {
        5 + 3 * (1 << max_depth)
    }
}

impl WorldcoinIntermediateAggregationInput {
    pub fn build(
        self,
        stage: CircuitBuilderStage,
        circuit_params: AggregationCircuitParams,
        kzg_params: &ParamsKZG<Bn256>,
    ) -> Result<WorldcoinIntermediateAggregationCircuit> {
        let num_proofs = self.num_proofs;
        let max_depth = self.max_depth;
        let initial_depth = self.initial_depth;
        log::info!(
            "New WorldcoinIntermediateAggregationCircuit | num_proofs: {num_proofs} | max_depth: {max_depth} | initial_depth: {initial_depth}"
        );
        let prev_acc_indices = get_accumulator_indices(&self.snarks);
        if self.max_depth == self.initial_depth + 1
            && prev_acc_indices.iter().any(|indices| !indices.is_empty())
        {
            bail!("Snarks to be aggregated must not have accumulators: they should come from WorldcoinLeafCircuit");
        }
        if self.max_depth > self.initial_depth + 1
            && prev_acc_indices
                .iter()
                .any(|indices| indices.len() != NUM_FE_ACCUMULATOR)
        {
            bail!("Snarks to be aggregated must all be WorldcoinIntermediateAggregationCircuits");
        }
        let mut circuit = AggregationCircuit::new::<SHPLONK>(
            stage,
            circuit_params,
            kzg_params,
            self.snarks,
            VerifierUniversality::None,
        );
        let mut prev_instances = circuit.previous_instances().clone();

        // remove old accumulators
        for (prev_instance, acc_indices) in prev_instances.iter_mut().zip_eq(prev_acc_indices) {
            for i in acc_indices.into_iter().sorted().rev() {
                prev_instance.remove(i);
            }
        }

        let builder = &mut circuit.builder;

        let range = builder.range_chip();
        let ctx = builder.main(0);
        let num_proofs = ctx.load_witness(Fr::from(num_proofs as u64));

        let new_instances = Self::join_previous_instances::<Fr>(
            ctx,
            &range,
            prev_instances.try_into().unwrap(),
            num_proofs,
            max_depth,
        );

        if builder.assigned_instances.len() != 1 {
            bail!("should only have 1 instance column");
        }
        let assigned_instances = &mut builder.assigned_instances[0];

        assert_eq!(assigned_instances.len(), NUM_FE_ACCUMULATOR);

        assigned_instances.extend(new_instances);

        let num_instance_wo_accumulator = Self::get_num_instance(max_depth);

        assert_eq!(
            assigned_instances.len(),
            NUM_FE_ACCUMULATOR + num_instance_wo_accumulator
        );
        Ok(WorldcoinIntermediateAggregationCircuit(circuit))
    }
}
