use std::iter;

use axiom_eth::{
    halo2_base::{
        gates::{flex_gate::threads::parallelize_core, GateInstructions, RangeInstructions},
        AssignedValue,
    },
    mpt::MPTChip,
    rlc::circuit::builder::RlcCircuitBuilder,
    utils::{
        build_utils::aggregation::CircuitMetadata, eth_circuit::EthCircuitInstructions,
        keccak::decorator::RlcKeccakCircuitImpl,
    },
    Field,
};
use axiom_sdk::HiLo;
use itertools::Itertools;

use axiom_components::{
    groth16::{
        get_groth16_consts_from_max_pi, handle_single_groth16verify,
        types::{
            Groth16VerifierComponentProof, Groth16VerifierComponentVerificationKey,
            Groth16VerifierInput,
        },
        Groth16VerifierComponent, NUM_FE_PROOF,
    },
    utils::flatten::InputFlatten,
};

use std::{fmt::Debug, vec};

use axiom_circuit::utils::from_hi_lo;

use crate::constants::*;
use crate::{
    types::*,
    utils::{get_signal_hash, get_vk_hash},
};

pub type WorldcoinLeafCircuit<F> = RlcKeccakCircuitImpl<F, WorldcoinInput<F>>;

/// Data passed from phase0 to phase1
/// instances:
/// [0] start
/// [1] end
/// [2, 4) vkey_hash
/// [4] grant_id
/// [5] root
/// [6, 6 + 1 << max_depth) receiver_i
/// [6 + num_proofs, 6 + 2 * (1 << max_depth)) nullifier_hash_i
#[derive(Clone, Debug)]
pub struct WorldcoinWitness<F: Field> {
    pub start: AssignedValue<F>,
    pub end: AssignedValue<F>,
    pub vkey_hash: HiLo<AssignedValue<F>>,
    pub grant_id: AssignedValue<F>,
    pub root: AssignedValue<F>,
    pub receivers: Vec<AssignedValue<F>>,
    pub nullifier_hashes: Vec<AssignedValue<F>>,
}

impl<F: Field> CircuitMetadata for WorldcoinInput<F> {
    const HAS_ACCUMULATOR: bool = false;
    fn num_instance(&self) -> Vec<usize> {
        vec![6 + 2 * (1 << self.max_depth)]
    }
}

// TODO: clean up struct, mpt is not needed
impl<F: Field> EthCircuitInstructions<F> for WorldcoinInput<F> {
    type FirstPhasePayload = WorldcoinWitness<F>;

    fn virtual_assign_phase0(
        &self,
        builder: &mut RlcCircuitBuilder<F>,
        mpt: &MPTChip<F>,
    ) -> Self::FirstPhasePayload {
        let keccak = mpt.keccak();
        // ======== FIRST PHASE ===========
        let ctx = builder.base.main(0);
        let range = mpt.range();

        // ==== Assign =====
        let zero = ctx.load_zero();
        let one = ctx.load_constant(F::ONE);

        let end = ctx.load_witness(F::from(self.end as u64));
        let start = ctx.load_witness(F::from(self.start as u64));
        let num_proofs = range.gate().sub(ctx, end, start);
        let max_proofs = ctx.load_witness(F::from(1 << self.max_depth));
        let max_proofs_plus_one = range.gate().add(ctx, max_proofs, one);
        let root = ctx.load_witness(self.root);
        let grant_id = ctx.load_witness(self.grant_id);
        let receivers = ctx.assign_witnesses(self.receivers.clone());

        let mut groth16_verifier_inputs: Vec<Groth16VerifierInput<AssignedValue<F>>> = Vec::new();
        let num_public_inputs = ctx.load_witness(F::from(MAX_GROTH16_PI as u64 + 1));
        let constants = get_groth16_consts_from_max_pi(MAX_GROTH16_PI);

        for groth16_input in self.groth16_inputs.iter() {
            let input: Groth16Input<F> = groth16_input.clone().into();
            let vk = ctx.assign_witnesses(input.vkey_bytes);
            let proof = ctx.assign_witnesses(input.proof_bytes);
            let public_inputs = ctx.assign_witnesses(input.public_inputs);

            let groth16_verifiery_input: Groth16VerifierInput<AssignedValue<F>> =
                Groth16VerifierInput {
                    vk: Groth16VerifierComponentVerificationKey::unflatten(
                        vk,
                        constants.gamma_abc_g1_len,
                    ),
                    proof: Groth16VerifierComponentProof::unflatten(proof).unwrap(),
                    public_inputs,
                    num_public_inputs,
                };

            groth16_verifier_inputs.push(groth16_verifiery_input);
        }

        // constrain 0 < num_proofs <= max_proofs
        range.check_less_than(ctx, zero, num_proofs, 64);
        range.check_less_than(ctx, num_proofs, max_proofs_plus_one, 64);

        let vk_bytes: Vec<AssignedValue<F>> = groth16_verifier_inputs[0].vk.flatten();
        let vk_hash: HiLo<AssignedValue<F>> = get_vk_hash(ctx, range, keccak, vk_bytes);

        let mut nullifier_hashes: Vec<AssignedValue<F>> = Vec::new();

        // constrain the public inputs
        // pi[0] root
        // pi[3] grant_id
        // pi[2] signal_hash from receiver
        let max_proofs = 1 << self.max_depth as usize;
        for _i in 0..max_proofs {
            let public_inputs = &groth16_verifier_inputs[_i].public_inputs;
            ctx.constrain_equal(&public_inputs[0], &root);
            ctx.constrain_equal(&public_inputs[3], &grant_id);
            let receiver = receivers[_i];
            let signal_hash = get_signal_hash(ctx, range, keccak, &receiver);
            ctx.constrain_equal(&signal_hash, &public_inputs[2]);
            nullifier_hashes.push(public_inputs[1]);
        }

        // constrain groth16 verify success
        parallelize_core(
            builder.base.pool(0),
            groth16_verifier_inputs,
            |ctx, input| {
                let res = handle_single_groth16verify(
                    ctx,
                    range,
                    input,
                    LIMB_BITS,
                    NUM_LIMBS,
                    MAX_GROTH16_PI,
                );
                let success = from_hi_lo(ctx, range, res.1.success);
                ctx.constrain_equal(&success, &one);
            },
        );

        let assigned_instances = iter::empty()
            .chain([start, end])
            .chain([vk_hash.hi(), vk_hash.lo()])
            .chain([root, grant_id])
            .chain(receivers.clone())
            .chain(nullifier_hashes.clone())
            .collect_vec();

        builder.base.assigned_instances[0] = assigned_instances;

        WorldcoinWitness {
            start,
            end,
            vkey_hash: vk_hash,
            grant_id,
            root,
            receivers,
            nullifier_hashes,
        }
    }

    fn virtual_assign_phase1(
        &self,
        builder: &mut RlcCircuitBuilder<F>,
        mpt: &MPTChip<F>,
        witness: Self::FirstPhasePayload,
    ) {
        // do nothing
    }
}
