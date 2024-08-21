use std::iter;

use axiom_eth::{
    halo2_base::{
        gates::{flex_gate::threads::parallelize_core, GateInstructions, RangeInstructions},
        safe_types::SafeBool,
        AssignedValue,
    },
    halo2_proofs::plonk::Assigned,
    halo2curves::bn256::Fr,
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
    get_groth16_consts_from_max_pi, handle_single_groth16verify,
    types::{Groth16VerifierComponentProof, Groth16VerifierInput},
};

use axiom_components::utils::flatten::InputFlatten;

use crate::{
    circuit_factory::leaf::WorldcoinRequestLeaf, circuits::v1::leaf::WorldcoinLeafInput,
    constants::*, utils::compute_keccak_merkle_tree,
};
use crate::{
    types::*,
    utils::{get_signal_hash, get_vk_hash},
};
use axiom_components::groth16::types::Groth16VerifierComponentVerificationKey;
use std::{fmt::Debug, vec};

pub type WorldcoinLeafCircuitV2<F> = RlcKeccakCircuitImpl<F, WorldcoinLeafInputV2<F>>;

#[derive(Clone, Debug, Default)]
pub struct WorldcoinLeafInputV2<T: Copy>(pub WorldcoinLeafInput<T>);

impl From<WorldcoinRequestLeaf> for WorldcoinLeafInputV2<Fr> {
    fn from(input: WorldcoinRequestLeaf) -> Self {
        let input: WorldcoinLeafInput<Fr> = input.into();
        Self(input)
    }
}

impl<F: Field> CircuitMetadata for WorldcoinLeafInputV2<F> {
    const HAS_ACCUMULATOR: bool = false;
    fn num_instance(&self) -> Vec<usize> {
        vec![8]
    }
}

impl<F: Field> EthCircuitInstructions<F> for WorldcoinLeafInputV2<F> {
    type FirstPhasePayload = ();

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
        let WorldcoinLeafInput::<AssignedValue<F>> {
            start,
            end,
            root,
            num_public_inputs,
            claims,
            vk_bytes,
            max_depth,
        } = self.0.assign(ctx);

        // ==== Constraints ====
        // 0 <= start < end < 2^64
        range.range_check(ctx, start, 64);
        range.range_check(ctx, end, 64);
        range.check_less_than(ctx, start, end, 64);

        let num_proofs = gate.sub(ctx, end, start);
        let max_proofs = ctx.load_constant(F::from(1 << max_depth));
        let max_proofs_plus_one = gate.add(ctx, max_proofs, one);

        // constrain 0 < num_proofs <= max_proofs
        range.range_check(ctx, num_proofs, 64);
        range.check_less_than(ctx, num_proofs, max_proofs_plus_one, 64);

        let constants = get_groth16_consts_from_max_pi(MAX_GROTH16_PI);

        assert_eq!(vk_bytes.len(), constants.num_fe_hilo_vkey);

        let vk_hash: HiLo<AssignedValue<F>> = get_vk_hash(ctx, range, keccak, vk_bytes.clone());

        let vk = Groth16VerifierComponentVerificationKey::unflatten(
            vk_bytes,
            constants.gamma_abc_g1_len,
        );

        let selector: Vec<SafeBool<F>> =
            unsafe_lt_mask(ctx, gate, num_proofs, 1 << self.0.max_depth);

        assert_eq!(
            claims.len(),
            selector.len(),
            "Collections must be of the same length"
        );

        let inputs: Vec<(ClaimInput<AssignedValue<F>>, SafeBool<F>)> =
            izip!(claims, selector).collect();

        let leaves = parallelize_core(builder.base.pool(0), inputs, |ctx, input| {
            let (claim, mask) = input;

            // pi[0] root
            // pi[1] nullifier_hash
            // pi[2] signal_hash from receiver
            // pi[3] grant_id
            let public_inputs =
                [root, claim.nullifier_hash, claim.receiver, claim.grant_id].to_vec();

            let groth16_verifier_input = Groth16VerifierInput {
                vk: vk.clone(),
                proof: Groth16VerifierComponentProof::unflatten(claim.proof_bytes).unwrap(),
                num_public_inputs,
                public_inputs: public_inputs.clone(),
            };

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
            let masked_grant_id = gate.mul(ctx, claim.grant_id, mask);
            let masked_receiver = gate.mul(ctx, claim.receiver, mask);
            let masked_nullifier_hash = gate.mul(ctx, public_inputs[1], mask);
            bytes.extend(uint_to_bytes_be(ctx, range, &masked_grant_id, 32));
            bytes.extend(uint_to_bytes_be(ctx, range, &masked_receiver, 20));
            bytes.extend(uint_to_bytes_be(ctx, range, &masked_nullifier_hash, 32));
            let bytes = bytes.iter().map(|sb| *sb.as_ref()).collect();
            let keccak_hash = keccak.keccak_fixed_len(ctx, bytes);

            HiLo::from_hi_lo([keccak_hash.output_hi, keccak_hash.output_lo])
        });

        let ctx = builder.base.main(0);

        let merkle_tree = compute_keccak_merkle_tree(ctx, range, keccak, leaves);
        let claim_root = merkle_tree[0];

        // instances:
        // [0] start
        // [1] end
        // [2, 3] vkey_hash
        // [4] root
        // [5, 6] claim_root
        // leaves being keccak256(abi.encodePacked(receiver_i, nullifierHash_i))
        // Leaves with indices greater than num_proofs - 1 are given by keccak256(abi.encodePacked(address(0), bytes32(0)))
        let assigned_instances = iter::empty()
            .chain([start, end])
            .chain(vk_hash.hi_lo())
            .chain([root])
            .chain(claim_root.hi_lo())
            .collect_vec();

        builder.base.assigned_instances[0] = assigned_instances;

        ()
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
