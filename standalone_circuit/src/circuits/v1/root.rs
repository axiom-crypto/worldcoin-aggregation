//! The root of the aggregation tree.
//! An [WorldcoinRootAggregationCircuit] can aggregate either:
//! - two [WorldcoinLeafnCircuit]s (if `max_depth == initial_depth + 1`) or
//! - two [WorldcoinIntermediateAggregationCircuit]s.
//!
//! The difference between Intermediate and Root aggregation circuits is that they expose different public outputs. Root aggregation
//! exposes the hash of the output [vk_hash_hi, vk_hash_lo, root, num_proofs, ...grant_ids, ...receivers, ...nullifier_hashes]

use std::ptr::null;

use anyhow::{bail, Result};
use axiom_eth::{
    halo2_base::{
        gates::{flex_gate::threads::parallelize_core, GateInstructions, RangeInstructions},
        safe_types::SafeBool,
        AssignedValue,
    },
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
        circuit_utils::unsafe_lt_mask,
        eth_circuit::EthCircuitInstructions,
        hilo::HiLo,
        keccak::decorator::RlcKeccakCircuitImpl,
        snark_verifier::{get_accumulator_indices, NUM_FE_ACCUMULATOR},
        uint_to_bytes_be,
    },
};

use itertools::{izip, Itertools};

use crate::utils::compute_keccak_for_branch_nodes;

use super::intermediate::WorldcoinIntermediateAggregationInput;

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
            initial_depth: _,
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

        let new_instances = WorldcoinIntermediateAggregationInput::join_previous_instances::<Fr>(
            ctx,
            &range,
            previous_instances.try_into().unwrap(),
            num_proofs,
            max_depth,
        );

        let gate = range.gate();

        let selector: Vec<SafeBool<Fr>> = unsafe_lt_mask(ctx, gate, num_proofs, 1 << max_depth);

        let mut public_inputs: Vec<[AssignedValue<Fr>; 3]> = Vec::new();

        // pi[0] root
        // pi[1] nullifier_hash
        // pi[2] signal_hash from receiver
        // pi[3] grant_id
        let root = new_instances[4];

        let max_proofs: usize = 1 << max_depth;
        for i in 0..max_proofs {
            let grant_id = new_instances[5 + i];
            let receiver = new_instances[5 + max_proofs + i];
            let nullifier_hash = new_instances[5 + 2 * max_proofs + i];

            public_inputs.push([nullifier_hash, receiver, grant_id]);
        }

        let inputs: Vec<([AssignedValue<Fr>; 3], SafeBool<Fr>)> =
            izip!(public_inputs, selector).collect();

        let mut leaves = parallelize_core(builder.base.pool(0), inputs, |ctx, input| {
            let (public_inputs, mask) = input;

            let [nullifier_hash, receiver, grant_id] = public_inputs;

            // use mask to calculate the correct leaf
            // Leaves: keccak256(abi.encodePacked(grant_ids_i, receivers_i, nullifierHashes_i))
            // Leaves with indices greater than num_proofs - 1 are given by keccak256(abi.encodePacked(uint256(0), address(0), bytes32(0)))
            let mut bytes = Vec::new();
            let masked_grant_id = gate.mul(ctx, grant_id, mask);
            let masked_receiver = gate.mul(ctx, receiver, mask);
            let masked_nullifier_hash = gate.mul(ctx, nullifier_hash, mask);
            bytes.extend(uint_to_bytes_be(ctx, range, &masked_grant_id, 32));
            bytes.extend(uint_to_bytes_be(ctx, range, &masked_receiver, 20));
            bytes.extend(uint_to_bytes_be(ctx, range, &masked_nullifier_hash, 32));
            let bytes = bytes.iter().map(|sb| *sb.as_ref()).collect();
            let keccak_hash = keccak.keccak_fixed_len(ctx, bytes);

            HiLo::from_hi_lo([keccak_hash.output_hi, keccak_hash.output_lo])
        });

        assert!(leaves.len().is_power_of_two());

        while (leaves.len() > 1) {
            let inputs = leaves.chunks(2).collect();

            leaves = parallelize_core(builder.base.pool(0), inputs, |ctx, input| {
                let left = input[0];
                let right = input[1];
                compute_keccak_for_branch_nodes(ctx, range, keccak, &left, &right)
            });
        }
        let claim_root = leaves[0];

        //let ctx: &mut axiom_eth::halo2_base::Context<Fr> = builder.base.main(0);

        // output:  [vk_hash_hi, vk_hash_lo, root, num_proofs, ...grant_ids, ...receivers, ...nullifier_hashes]
        // let mut output: Vec<AssignedValue<Fr>> = Vec::new();
        // output.extend(new_instances[2..5].to_vec());
        // output.extend([num_proofs].to_vec());
        // output.extend(claim_root.hi_lo());
        //output.extend(new_instances[5..5 + 3 * (1 << max_depth)].to_vec());

        // // generate keccak hash for the outputs
        // let output_bytes: Vec<AssignedValue<Fr>> = output
        //     .iter()
        //     .map(|b| {
        //         let bytes: Vec<AssignedValue<Fr>> = uint_to_bytes_be(ctx, range, b, 32)
        //             .iter()
        //             .map(|sb| *sb.as_ref())
        //             .collect();
        //         bytes
        //     })
        //     .flatten()
        //     .collect();

        // assert_eq!(output_bytes.len(), 32 * (4 + 3 * (1 << max_depth)));

        // let output_hash = keccak.keccak_fixed_len(ctx, output_bytes);

        let assigned_instances: &mut Vec<AssignedValue<Fr>> =
            &mut builder.base.assigned_instances[0];

        assigned_instances.extend(accumulator);
        assigned_instances.extend(new_instances[2..5].to_vec());
        assigned_instances.extend([num_proofs].to_vec());
        assigned_instances.extend(claim_root.hi_lo());
        //assigned_instances.extend([output_hash.output_hi, output_hash.output_lo]);

        assert_eq!(assigned_instances.len(), NUM_FE_ACCUMULATOR + 6);
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
        vec![NUM_FE_ACCUMULATOR + 6]
    }
}
