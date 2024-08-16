use std::iter;

use axiom_eth::{
    halo2_base::{
        gates::{flex_gate::threads::parallelize_core, GateInstructions, RangeInstructions},
        safe_types::SafeBool,
        AssignedValue, Context,
    },
    mpt::MPTChip,
    rlc::circuit::builder::RlcCircuitBuilder,
    utils::{
        build_utils::aggregation::CircuitMetadata, circuit_utils::unsafe_lt_mask,
        eth_circuit::EthCircuitInstructions, hilo::HiLo, keccak::decorator::RlcKeccakCircuitImpl,
        uint_to_bytes_be,
    },
    Field,
};

use itertools::{izip, Itertools};

use axiom_components::groth16::{
    get_groth16_consts_from_max_pi, handle_single_groth16verify, types::Groth16VerifierInput,
};

use std::{fmt::Debug, vec};

use crate::{constants::*, utils::compute_keccak_merkle_tree};
use crate::{
    types::*,
    utils::{get_signal_hash, get_vk_hash},
};

pub type WorldcoinLeafCircuitV2<F> = RlcKeccakCircuitImpl<F, WorldcoinLeafInputV2<F>>;

/// Data passed from phase0 to phase1
/// instances:
/// [0] start
/// [1] end
/// [2, 3] vkey_hash
/// [4] grant_id
/// [5] root
/// [6, 7] claim_root
/// leaves being keccak256(abi.encodePacked(receiver_i, nullifierHash_i))
/// Leaves with indices greater than num_proofs - 1 are given by keccak246(abi.encodePacked(address(0), bytes32(0)))
#[derive(Clone, Debug)]
pub struct WorldcoinWitnessV2<F: Field> {
    pub start: AssignedValue<F>,
    pub end: AssignedValue<F>,
    pub vkey_hash: HiLo<AssignedValue<F>>,
    pub grant_id: AssignedValue<F>,
    pub root: AssignedValue<F>,
    pub claim_root: HiLo<AssignedValue<F>>,
}

#[derive(Clone, Debug, Default)]
pub struct WorldcoinLeafInputV2<T: Copy>(WorldcoinLeafInput<T>);

impl<F: Field> CircuitMetadata for WorldcoinLeafInputV2<F> {
    const HAS_ACCUMULATOR: bool = false;
    fn num_instance(&self) -> Vec<usize> {
        vec![8]
    }
}

impl<F: Field> EthCircuitInstructions<F> for WorldcoinLeafInputV2<F> {
    type FirstPhasePayload = WorldcoinWitnessV2<F>;

    fn virtual_assign_phase0(
        &self,
        builder: &mut RlcCircuitBuilder<F>,
        mpt: &MPTChip<F>,
    ) -> Self::FirstPhasePayload {
        let keccak = mpt.keccak();
        // ======== FIRST PHASE ===========
        let ctx = builder.base.main(0);
        let range = mpt.range();
        let gate = range.gate();

        // ==== Assign =====
        let zero = ctx.load_zero();
        let one = ctx.load_constant(F::ONE);
        let WorldcoinAssignedInput {
            start,
            end,
            root,
            grant_id,
            receivers,
            groth16_verifier_inputs,
        } = self.0.assign(ctx);

        // ==== Constraints ====

        // 0 <= start < end < 2^253
        range.range_check(ctx, start, 253);
        range.range_check(ctx, end, 253);
        range.check_less_than(ctx, start, end, 253);

        let num_proofs = gate.sub(ctx, end, start);
        let max_proofs = ctx.load_witness(F::from(1 << self.0.max_depth));
        let max_proofs_plus_one = gate.add(ctx, max_proofs, one);

        // constrain 0 < num_proofs <= max_proofs
        range.check_less_than(ctx, zero, num_proofs, 64);
        range.check_less_than(ctx, num_proofs, max_proofs_plus_one, 64);

        let constants = get_groth16_consts_from_max_pi(MAX_GROTH16_PI);
        let vk_bytes: Vec<AssignedValue<F>> = groth16_verifier_inputs[0].vk.flatten();

        assert_eq!(vk_bytes.len(), constants.num_fe_hilo_vkey);

        let vk_hash: HiLo<AssignedValue<F>> = get_vk_hash(ctx, range, keccak, vk_bytes.clone());

        let selector: Vec<SafeBool<F>> =
            unsafe_lt_mask(ctx, gate, num_proofs, 1 << self.0.max_depth);

        assert_eq!(
            groth16_verifier_inputs.len(),
            receivers.len(),
            "Collections must be of the same length"
        );
        assert_eq!(
            receivers.len(),
            selector.len(),
            "Collections must be of the same length"
        );

        let inputs: Vec<(
            Groth16VerifierInput<AssignedValue<F>>,
            AssignedValue<F>,
            SafeBool<F>,
        )> = izip!(groth16_verifier_inputs, receivers, selector).collect();

        let leaves = parallelize_core(builder.base.pool(0), inputs, |ctx, input| {
            let (groth16_verifier_input, receiver, mask) = input;

            // constrain proofs using the same vkey
            let flattened_vk: Vec<AssignedValue<F>> = groth16_verifier_input.vk.flatten();
            assert_eq!(flattened_vk.len(), constants.num_fe_hilo_vkey);
            flattened_vk
                .iter()
                .zip(&vk_bytes)
                .for_each(|(a, b)| ctx.constrain_equal(a, b));

            // constrain the public inputs
            // pi[0] root
            // pi[1] nullifier_hash
            // pi[2] signal_hash from receiver
            // pi[3] grant_id
            let public_inputs = groth16_verifier_input.public_inputs.clone();
            ctx.constrain_equal(&public_inputs[0], &root);
            ctx.constrain_equal(&public_inputs[3], &grant_id);
            let receiver = receiver;
            let signal_hash = get_signal_hash(ctx, range, keccak, &receiver);
            ctx.constrain_equal(&signal_hash, &public_inputs[2]);

            // constrain groth16 verify success
            let res = handle_single_groth16verify(
                ctx,
                range,
                groth16_verifier_input,
                LIMB_BITS,
                NUM_LIMBS,
                MAX_GROTH16_PI,
            );
            let success = res.1.success;
            ctx.constrain_equal(&success.hi(), &zero);
            ctx.constrain_equal(&success.lo(), &one);

            // use mask to calculate the correct leaf
            // Leaves: keccak256(abi.encodePacked(receiver_i, nullifierHash_i))
            // Leaves with indices greater than num_proofs - 1 are given by keccak256(abi.encodePacked(address(0), bytes32(0)))
            let mut bytes = Vec::new();
            let masked_receiver = gate.mul(ctx, receiver, mask);
            let receiver_bytes = uint_to_bytes_be(ctx, range, &masked_receiver, 20);
            let masked_nullifier_hash = gate.mul(ctx, public_inputs[1], mask);
            let nullifier_hash_bytes = uint_to_bytes_be(ctx, range, &masked_nullifier_hash, 32);
            bytes.extend(receiver_bytes.iter().map(|sb| *sb.as_ref()));
            bytes.extend(nullifier_hash_bytes.iter().map(|sb| *sb.as_ref()));

            let keccak_hash = keccak.keccak_fixed_len(ctx, bytes);

            HiLo::from_hi_lo([keccak_hash.output_hi, keccak_hash.output_lo])
        });

        let merkle_tree = compute_keccak_merkle_tree(ctx, range, keccak, leaves);
        let claim_root = merkle_tree[0];

        let assigned_instances = iter::empty()
            .chain([start, end])
            .chain(vk_hash.hi_lo())
            .chain([grant_id, root])
            .chain(claim_root.hi_lo())
            .collect_vec();

        builder.base.assigned_instances[0] = assigned_instances;

        WorldcoinWitnessV2 {
            start,
            end,
            vkey_hash: vk_hash,
            grant_id,
            root,
            claim_root,
        }
    }

    fn virtual_assign_phase1(
        &self,
        _builder: &mut RlcCircuitBuilder<F>,
        _mpt: &MPTChip<F>,
        _witness: Self::FirstPhasePayload,
    ) {
        // do nothing
    }
}
