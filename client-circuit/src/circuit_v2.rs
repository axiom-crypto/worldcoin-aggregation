use crate::constants::*;
use crate::types::WorldcoinInput;
use ethers::providers::JsonRpcClient;
use std::{
    convert::TryInto,
    fmt::Debug,
    sync::{Arc, Mutex},
};

use axiom_circuit::{
    scaffold::AxiomCircuitScaffold,
    subquery::{caller::SubqueryCaller, groth16::Groth16AssignedInput},
    utils::{from_hi_lo, to_hi_lo},
};

use axiom_eth::{keccak::promise::KeccakFixLenCall, utils::uint_to_bytes_be, Field};

use axiom_sdk::{
    halo2_base::{
        gates::{RangeChip, RangeInstructions},
        safe_types::{FixLenBytesVec, SafeByte},
        AssignedValue, Context,
    },
    HiLo,
};

use crate::utils::{get_signal_hash, get_vk_hash};

#[derive(Debug, Clone, Default)]
pub struct WorldcoinV2Circuit;

impl<P: JsonRpcClient, F: Field> AxiomCircuitScaffold<P, F> for WorldcoinV2Circuit {
    type InputValue = WorldcoinInput<F, MAX_PROOFS>;
    type InputWitness = WorldcoinInput<AssignedValue<F>, MAX_PROOFS>;

    type FirstPhasePayload = ();

    fn virtual_assign_phase0(
        builder: &mut axiom_circuit::axiom_eth::rlc::circuit::builder::RlcCircuitBuilder<F>,
        range: &RangeChip<F>,
        subquery_caller: Arc<Mutex<SubqueryCaller<P, F>>>,
        callback: &mut Vec<HiLo<AssignedValue<F>>>,
        assigned_inputs: Self::InputWitness,
        _: Self::CoreParams,
    ) -> Self::FirstPhasePayload {
        let ctx = builder.base.main(0);

        let zero = ctx.load_zero();
        let one = ctx.load_constant(F::ONE);

        range.check_less_than(ctx, zero, assigned_inputs.num_proofs, 64);

        let max_proofs_plus_one = ctx.load_constant(F::from((MAX_PROOFS + 1) as u64));
        range.check_less_than(ctx, assigned_inputs.num_proofs, max_proofs_plus_one, 64);

        let vkey_bytes = &assigned_inputs.groth16_inputs[0].vkey_bytes;
        assert!(vkey_bytes.len() == NUM_FE_VKEY);

        let vkey_hash = get_vk_hash(ctx, range, &subquery_caller, vkey_bytes);

        callback.push(vkey_hash);
        callback.push(to_hi_lo(ctx, range, assigned_inputs.grant_id));
        callback.push(to_hi_lo(ctx, range, assigned_inputs.root));

        let mut leaves: Vec<HiLo<AssignedValue<F>>> = Vec::new();

        let num_proofs: usize = usize::from_le_bytes(
            // 8 bytes as usize
            assigned_inputs.num_proofs.value().to_bytes_le()[0..8]
                .try_into()
                .unwrap(),
        );

        for i in 0..num_proofs {
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

            let mut bytes = Vec::new();
            let receiver_bytes = uint_to_bytes_be(ctx, range, &receiver, 20);
            let nullifier_hash_bytes = uint_to_bytes_be(ctx, range, &public_inputs[1], 32);
            bytes.extend(receiver_bytes);
            bytes.extend(nullifier_hash_bytes);

            let keccak_input = FixLenBytesVec::<F>::new(bytes, 52);
            let keccak_subquery: KeccakFixLenCall<F> = KeccakFixLenCall::new(keccak_input);

            let keccak_result = subquery_caller.lock().unwrap().keccak(ctx, keccak_subquery);
            leaves.push(keccak_result);
        }

        // Pad the leaves to MAX_PROOFs
        let mut pad_bytes: Vec<SafeByte<F>> = Vec::new();
        pad_bytes.append(&mut uint_to_bytes_be(ctx, range, &zero, 20));
        pad_bytes.append(&mut uint_to_bytes_be(ctx, range, &zero, 32));
        let pad_keccak_input = FixLenBytesVec::<F>::new(pad_bytes, 52);
        let pad_keccak_subquery: KeccakFixLenCall<F> = KeccakFixLenCall::new(pad_keccak_input);
        let pad_leave = subquery_caller
            .lock()
            .unwrap()
            .keccak(ctx, pad_keccak_subquery);
        for i in num_proofs..MAX_PROOFS {
            leaves.push(pad_leave);
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
    // Also implict len > 0
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
            bytes.extend(uint_to_bytes_be(ctx, range, &c[1].hi(), 16));
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
