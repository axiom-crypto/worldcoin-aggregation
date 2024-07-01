use crate::constants::*;
use crate::types::{WorldcoinInput, WorldcoinInputCoreParams};
use ethers::providers::JsonRpcClient;
use std::{
    fmt::Debug,
    sync::{Arc, Mutex},
};

use axiom_circuit::{
    scaffold::AxiomCircuitScaffold,
    subquery::{caller::SubqueryCaller, groth16::Groth16AssignedInput},
    utils::{from_hi_lo, to_hi_lo},
};

use axiom_eth::{
    keccak::promise::KeccakFixLenCall, utils::circuit_utils::unsafe_lt_mask,
    utils::uint_to_bytes_be, Field,
};

use axiom_sdk::{
    halo2_base::{
        gates::{GateInstructions, RangeChip, RangeInstructions},
        safe_types::{FixLenBytesVec, SafeByte},
        AssignedValue, Context,
    },
    HiLo,
};

use crate::utils::{get_signal_hash, get_vk_hash};

#[derive(Debug, Clone, Default)]
pub struct WorldcoinV2Circuit;

impl<P: JsonRpcClient, F: Field> AxiomCircuitScaffold<P, F> for WorldcoinV2Circuit {
    type InputValue = WorldcoinInput<F>;
    type InputWitness = WorldcoinInput<AssignedValue<F>>;
    type CoreParams = WorldcoinInputCoreParams;

    type FirstPhasePayload = ();

    fn virtual_assign_phase0(
        builder: &mut axiom_circuit::axiom_eth::rlc::circuit::builder::RlcCircuitBuilder<F>,
        range: &RangeChip<F>,
        subquery_caller: Arc<Mutex<SubqueryCaller<P, F>>>,
        callback: &mut Vec<HiLo<AssignedValue<F>>>,
        assigned_inputs: Self::InputWitness,
        params: Self::CoreParams,
    ) -> Self::FirstPhasePayload {
        let ctx = builder.base.main(0);
        let gate = range.gate();
        let zero = ctx.load_zero();
        let one = ctx.load_constant(F::ONE);

        let max_proofs = params.max_proofs;
        range.check_less_than(ctx, zero, assigned_inputs.num_proofs, 64);
        let max_proofs_plus_one = ctx.load_constant(F::from((max_proofs + 1) as u64));
        range.check_less_than(ctx, assigned_inputs.num_proofs, max_proofs_plus_one, 64);

        let vkey_bytes = &assigned_inputs.groth16_inputs[0].vkey_bytes;
        assert!(vkey_bytes.len() == NUM_FE_VKEY);

        let vkey_hash = get_vk_hash(ctx, range, &subquery_caller, vkey_bytes);

        callback.push(vkey_hash);
        callback.push(to_hi_lo(ctx, range, assigned_inputs.grant_id));
        callback.push(to_hi_lo(ctx, range, assigned_inputs.root));

        // mask to only take first num_proofs, set all else equal 0
        let masks = unsafe_lt_mask(ctx, gate, assigned_inputs.num_proofs, max_proofs);

        let mut leaves = Vec::with_capacity(max_proofs);

        for i in 0..max_proofs {
            let assigned_groth16_input = &assigned_inputs.groth16_inputs[i];
            let public_inputs = &assigned_groth16_input.public_inputs;

            if i != 0 {
                let curr_vkey_bytes = &assigned_groth16_input.vkey_bytes;
                assert!(curr_vkey_bytes.len() == NUM_FE_VKEY);

                for _vkey_idx in 0..NUM_FE_VKEY {
                    ctx.constrain_equal(&curr_vkey_bytes[_vkey_idx], &vkey_bytes[_vkey_idx]);
                }
            }

            ctx.constrain_equal(&public_inputs[3], &assigned_inputs.grant_id);
            ctx.constrain_equal(&public_inputs[0], &assigned_inputs.root);

            let verify = subquery_caller.lock().unwrap().groth16_verify(
                ctx,
                range,
                Groth16AssignedInput {
                    vkey_bytes: assigned_groth16_input.vkey_bytes.clone(),
                    proof_bytes: assigned_groth16_input.proof_bytes.clone(),
                    public_inputs: assigned_groth16_input.public_inputs.clone(),
                },
            );
            let verify = from_hi_lo(ctx, range, verify);
            ctx.constrain_equal(&verify, &one);

            let receiver = assigned_inputs.receivers[i];
            let signal_hash = get_signal_hash(ctx, range, &subquery_caller, &receiver);
            ctx.constrain_equal(&signal_hash, &public_inputs[2]);

            let mask = masks[i];
            let mut bytes = Vec::new();

            // with mask, when i >= num_proofs, the leave is keccak([address(0), bytes32(0)])
            let masked_receiver = gate.mul(ctx, receiver, mask);
            let receiver_bytes = uint_to_bytes_be(ctx, range, &masked_receiver, 20);
            let masked_nullifier_hash = gate.mul(ctx, public_inputs[1], mask);
            let nullifier_hash_bytes = uint_to_bytes_be(ctx, range, &masked_nullifier_hash, 32);

            bytes.extend(receiver_bytes);
            bytes.extend(nullifier_hash_bytes);

            let keccak_input = FixLenBytesVec::<F>::new(bytes, 52);
            let keccak_subquery: KeccakFixLenCall<F> = KeccakFixLenCall::new(keccak_input);
            let keccak_result = subquery_caller.lock().unwrap().keccak(ctx, keccak_subquery);
            leaves.push(keccak_result);
        }

        let merkle_tree = compute_keccak_merkle_tree(ctx, range, &subquery_caller, leaves);
        callback.push(merkle_tree[0]);
    }
}

// construct a merkle tree from leaves
// return vec is [root, ...[depth 1 nodes], ...[depth 2 nodes], ..., ...[leaves]]
pub fn compute_keccak_merkle_tree<P: JsonRpcClient, F: Field>(
    ctx: &mut Context<F>,
    range: &RangeChip<F>,
    subquery_caller: &Arc<Mutex<SubqueryCaller<P, F>>>,
    leaves: Vec<HiLo<AssignedValue<F>>>,
) -> Vec<HiLo<AssignedValue<F>>> {
    let len = leaves.len();
    // Also implicit len > 0
    assert!(len.is_power_of_two());
    if len == 1 {
        return leaves;
    }
    let next_level = leaves
        .chunks(2)
        .map(|c| {
            let mut bytes: Vec<SafeByte<F>> = Vec::new();
            bytes.extend(uint_to_bytes_be(ctx, range, &c[0].hi(), 16));
            bytes.extend(uint_to_bytes_be(ctx, range, &c[0].lo(), 16));
            bytes.extend(uint_to_bytes_be(ctx, range, &c[1].hi(), 16));
            bytes.extend(uint_to_bytes_be(ctx, range, &c[1].lo(), 16));
            let keccak_input = FixLenBytesVec::<F>::new(bytes, 64);
            let keccak_subquery: KeccakFixLenCall<F> = KeccakFixLenCall::new(keccak_input);
            subquery_caller.lock().unwrap().keccak(ctx, keccak_subquery)
        })
        .collect();
    let mut ret: Vec<HiLo<AssignedValue<F>>> =
        compute_keccak_merkle_tree(ctx, range, subquery_caller, next_level);
    ret.extend(leaves);
    ret
}
