//! The root of the aggregation tree.
//! An [WorldcoinRootAggregationCircuit] can aggregate either:
//! - two [WorldcoinLeafnCircuit]s (if `max_depth == initial_depth + 1`) or
//! - two [WorldcoinIntermediateAggregationCircuit]s.
//!
//! The difference between Intermediate and Root aggregation circuits is that they expose different public outputs. Root aggregation
//! exposes the hash of the output [vk_hash_hi, vk_hash_lo, grant_id, root, num_proofs, ...receivers, ...nullifier_hashes]

use anyhow::{bail, Result};
use axiom_eth::{
    halo2_base::AssignedValue,
    halo2_proofs::poly::{commitment::ParamsProver, kzg::commitment::ParamsKZG},
    halo2curves::bn256::{Bn256, Fr},
    mpt::MPTChip,
    rlc::circuit::builder::RlcCircuitBuilder,
    snark_verifier_sdk::{
        halo2::aggregation::{aggregate_snarks, SnarkAggregationOutput, Svk, VerifierUniversality},
        Snark, SHPLONK,
    },
    utils::{
        build_utils::aggregation::CircuitMetadata,
        eth_circuit::EthCircuitInstructions,
        keccak::decorator::RlcKeccakCircuitImpl,
        snark_verifier::{get_accumulator_indices, NUM_FE_ACCUMULATOR},
        uint_to_bytes_be,
    },
};

use itertools::Itertools;

use super::intermediate::{join_previous_instances, WorldcoinIntermediateAggregationInput};

pub type WorldcoinRootAggregationCircuit = RlcKeccakCircuitImpl<Fr, WorldcoinRootAggregationInput>;

#[derive(Clone, Debug)]
pub struct WorldcoinRootAggregationInput {
    pub inner: WorldcoinIntermediateAggregationInput,
    pub svk: Svk,
    prev_acc_indices: Vec<Vec<usize>>,
}

impl WorldcoinRootAggregationInput {
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
            bail!("Snarks to be aggregated must not have accumulators: they should come from WorldcoinLeafCircuit");
        }
        if max_depth > initial_depth + 1
            && prev_acc_indices
                .iter()
                .any(|indices| indices.len() != NUM_FE_ACCUMULATOR)
        {
            bail!("Snarks to be aggregated must all be WorldcoinIntermediateAggregationCircuit");
        }
        let inner = WorldcoinIntermediateAggregationInput::new(
            snarks,
            num_proofs,
            max_depth,
            initial_depth,
        );
        Ok(Self {
            inner,
            svk,
            prev_acc_indices,
        })
    }
}

impl EthCircuitInstructions<Fr> for WorldcoinRootAggregationInput {
    type FirstPhasePayload = ();

    fn virtual_assign_phase0(
        &self,
        builder: &mut RlcCircuitBuilder<Fr>,
        mpt: &MPTChip<Fr>,
    ) -> Self::FirstPhasePayload {
        let WorldcoinIntermediateAggregationInput {
            max_depth,
            initial_depth,
            num_proofs,
            snarks,
        } = self.inner.clone();

        let keccak = mpt.keccak();
        let range = keccak.range();
        let pool = builder.base.pool(0);
        let SnarkAggregationOutput {
            mut previous_instances,
            accumulator,
            ..
        } = aggregate_snarks::<SHPLONK>(pool, range, self.svk, snarks, VerifierUniversality::None);

        // remove old accumulators
        for (prev_instance, acc_indices) in
            previous_instances.iter_mut().zip_eq(&self.prev_acc_indices)
        {
            for i in acc_indices.iter().sorted().rev() {
                prev_instance.remove(*i);
            }
        }

        let ctx = pool.main();

        let num_proofs = ctx.load_witness(Fr::from(num_proofs as u64));

        let new_instances = join_previous_instances::<Fr>(
            ctx,
            &range,
            previous_instances.try_into().unwrap(),
            num_proofs,
            max_depth,
            initial_depth,
        );

        // output:  [vk_hash_hi, vk_hash_lo, grant_id, root, num_proofs, ...receivers, ...nullifier_hashes]
        let mut output: Vec<AssignedValue<Fr>> = Vec::new();
        output.extend(new_instances[2..6].to_vec());
        output.extend([num_proofs].to_vec());
        output.extend(new_instances[6..6 + 2 * (1 << max_depth)].to_vec());

        // generate keccak hash for the outputs
        let output_bytes: Vec<AssignedValue<Fr>> = output
            .iter()
            .map(|b| {
                let bytes: Vec<AssignedValue<Fr>> = uint_to_bytes_be(ctx, range, b, 32)
                    .iter()
                    .map(|sb| *sb.as_ref())
                    .collect();
                bytes
            })
            .flatten()
            .collect();

        assert_eq!(output_bytes.len(), 32 * (5 + 2 * (1 << max_depth)));

        let output_hash = keccak.keccak_fixed_len(ctx, output_bytes);

        let assigned_instances: &mut Vec<AssignedValue<Fr>> =
            &mut builder.base.assigned_instances[0];

        assigned_instances.extend(accumulator);
        assigned_instances.extend([output_hash.output_hi, output_hash.output_lo]);

        assert_eq!(assigned_instances.len(), NUM_FE_ACCUMULATOR + 2);
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

impl CircuitMetadata for WorldcoinRootAggregationInput {
    const HAS_ACCUMULATOR: bool = true;

    fn num_instance(&self) -> Vec<usize> {
        vec![NUM_FE_ACCUMULATOR + 2]
    }
}
