//! Intermediate aggregation circuits that aggregate in a binary tree topology:
//! The leaves of the tree are formed by [WorldcoinLeafCircuit]s, and intermediate notes
//! of the tree are formed by [WorldcoinIntermediateAggreagtionCircuit]s.
//!
//! An [WorldcoinIntermediateAggregationCircuit] can aggregate either:
//! - two [WorldcoinLeafCircuit]s or
//! - two [WorldcoinIntermediateAggreagtionCircuit]s.
//!
//! The root of the aggregation tree will be a [WorldcoinRootAggregationCircuit].
//! The difference between Intermediate and Root aggregation circuits has different public outputs.
//! RootAggregation exposes num_proofs instead start/end.
use anyhow::{bail, Ok, Result};
use axiom_eth::{
    halo2_base::{
        gates::{circuit::CircuitBuilderStage, GateInstructions, RangeChip, RangeInstructions},
        AssignedValue, Context,
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

pub struct WorldcoinIntermediateAggregationCircuitV1(pub AggregationCircuit);

impl WorldcoinIntermediateAggregationCircuitV1 {
    /// The number of instances NOT INCLUDING the accumulator
    pub fn get_num_instance(max_depth: usize, initial_depth: usize) -> usize {
        assert!(max_depth >= initial_depth);
        6 + 2 * (1 << max_depth)
    }
}

/// The input to create an intermediate [AggregationCircuit] that aggregates [WorldcoinLeafCircuitV1]s.
/// These are intemediate aggregations because they do not perform additional keccaks. Therefore the public instance format (after excluding accumulators) is
/// different from that of the original [WorldcoinLeafCircuitV1]s.
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
}

impl WorldcoinIntermediateAggregationInput {
    pub fn build(
        self,
        stage: CircuitBuilderStage,
        circuit_params: AggregationCircuitParams,
        kzg_params: &ParamsKZG<Bn256>,
    ) -> Result<WorldcoinIntermediateAggregationCircuitV1> {
        let circuit = self
            .build_aggregation_circuit(stage, circuit_params, kzg_params, false)
            .unwrap();
        Ok(WorldcoinIntermediateAggregationCircuitV1(circuit))
    }

    pub fn build_aggregation_circuit(
        self,
        stage: CircuitBuilderStage,
        circuit_params: AggregationCircuitParams,
        kzg_params: &ParamsKZG<Bn256>,
        expose_num_proofs: bool,
    ) -> Result<AggregationCircuit> {
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
        // TODO: slight computational overhead from recreating RangeChip; builder should store RangeChip as OnceCell
        let range = builder.range_chip();
        let ctx = builder.main(0);
        let num_proofs = ctx.load_witness(Fr::from(num_proofs as u64));

        let new_instances = join_previous_instances::<Fr>(
            ctx,
            &range,
            prev_instances.try_into().unwrap(),
            num_proofs,
            max_depth,
            initial_depth,
        );
        if builder.assigned_instances.len() != 1 {
            bail!("should only have 1 instance column");
        }
        let assigned_instances = &mut builder.assigned_instances[0];

        assert_eq!(assigned_instances.len(), NUM_FE_ACCUMULATOR);

        if !expose_num_proofs {
            assigned_instances.extend(new_instances);
            assert_eq!(
                assigned_instances.len(),
                NUM_FE_ACCUMULATOR + 6 + 2 * (1 << self.max_depth)
            );
        } else {
            // public IOs for WorldcoinRootAggregation circuit
            // vkeyHash, grant_id, root, num_proofs, receivers, nullifier_hashes
            assigned_instances.extend(new_instances[2..6].to_vec());
            assigned_instances.extend([num_proofs].to_vec());
            assigned_instances.extend(new_instances[6..6 + 2 * (1 << max_depth)].to_vec());
            assert_eq!(
                assigned_instances.len(),
                NUM_FE_ACCUMULATOR + 5 + 2 * (1 << self.max_depth)
            );
        }
        Ok(circuit)
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
/// [4] grant_id
/// [5] root
/// [6, 6 + 1 << max_depth - 1] receiver_i
/// [6 + num_proofs, 6 + 2 * (1 << max_depth)] nullifier_hash_i
pub fn join_previous_instances<F: Field>(
    ctx: &mut Context<F>,
    range: &RangeChip<F>,
    prev_instances: [Vec<AssignedValue<F>>; 2],
    num_proofs: AssignedValue<F>,
    max_depth: usize,
    initial_depth: usize,
) -> Vec<AssignedValue<F>> {
    let prev_depth = max_depth - 1;
    let num_instance_prev_depth =
        WorldcoinIntermediateAggregationCircuitV1::get_num_instance(prev_depth, initial_depth);
    assert_eq!(num_instance_prev_depth, prev_instances[0].len());
    assert_eq!(num_instance_prev_depth, prev_instances[1].len());

    let [instance0, instance1] = prev_instances;

    // join & sanitize block numbers
    let (start_block_number, intermed_block_num0) = (instance0[0], instance0[1]);
    let (intermed_block_num1, end_block_number) = (instance1[0], instance1[1]);
    let num_blocks0 = range
        .gate()
        .sub(ctx, intermed_block_num0, start_block_number);
    let num_blocks1 = range.gate().sub(ctx, end_block_number, intermed_block_num1);

    range.check_less_than_safe(ctx, num_blocks0, 1 << prev_depth + 1);
    range.check_less_than_safe(ctx, num_blocks1, 1 << prev_depth + 1);

    let boundary_num_diff = range.gate().sub(ctx, end_block_number, start_block_number);
    ctx.constrain_equal(&boundary_num_diff, &num_proofs);

    let num_instance =
        WorldcoinIntermediateAggregationCircuitV1::get_num_instance(max_depth, initial_depth);
    let mut instances = Vec::with_capacity(num_instance);

    // constrain vkeyHash, grant_id, root to be equal for the deps
    // which is idx 2..6
    for _i in 2..6 {
        ctx.constrain_equal(&instance0[_i], &instance1[_i]);
    }

    println!("instances from previous shards are the same");

    // new instances for the aggregation layer
    instances.push(start_block_number);
    instances.push(end_block_number);
    instances.extend_from_slice(&instance0[2..6]);
    // combine receivers
    let max_proofs_prev_depth = 1 << prev_depth;
    instances.extend(&instance0[6..6 + max_proofs_prev_depth]);
    instances.extend(&instance1[6..6 + max_proofs_prev_depth]);

    // combine nullifier_hashes
    instances.extend(&instance0[6 + max_proofs_prev_depth..6 + 2 * max_proofs_prev_depth]);
    instances.extend(&instance1[6 + max_proofs_prev_depth..6 + 2 * max_proofs_prev_depth]);

    instances
}
