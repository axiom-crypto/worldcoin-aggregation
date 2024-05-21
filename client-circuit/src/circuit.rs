use crate::constants::*;
use crate::types::WorldcoinInput;
use axiom_components::groth16::{NULL_CHUNK_VAL, NUM_BYTES_PER_FE, NUM_FE_PER_CHUNK};
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
    keccak::promise::KeccakFixLenCall,
    utils::{uint_to_bytes_be, uint_to_bytes_le},
    Field,
};

use axiom_sdk::{
    halo2_base::{
        gates::{GateInstructions, RangeChip, RangeInstructions},
        safe_types::{FixLenBytesVec, SafeByte},
        utils::biguint_to_fe,
        AssignedValue, Context,
    },
    HiLo,
};

use std::cmp::min;

use num_bigint::BigUint;

#[derive(Debug, Clone, Default)]
pub struct WorldcoinCircuit;

impl<P: JsonRpcClient, F: Field> AxiomCircuitScaffold<P, F> for WorldcoinCircuit {
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
        callback.push(to_hi_lo(ctx, range, assigned_inputs.num_proofs));

        let mut receiver_vec: Vec<HiLo<AssignedValue<F>>> = Vec::new();
        let mut nullifier_hash_vec: Vec<HiLo<AssignedValue<F>>> = Vec::new();

        for i in 0..MAX_PROOFS {
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

            receiver_vec.push(to_hi_lo(ctx, range, receiver));
            nullifier_hash_vec.push(to_hi_lo(ctx, range, public_inputs[1]));
        }

        callback.append(&mut receiver_vec);
        callback.append(&mut nullifier_hash_vec);
    }
}

pub fn get_vk_hash<P: JsonRpcClient, F: Field>(
    ctx: &mut Context<F>,
    range: &RangeChip<F>,
    subquery_caller: &Arc<Mutex<SubqueryCaller<P, F>>>,
    vk_bytes: &Vec<AssignedValue<F>>,
) -> HiLo<AssignedValue<F>> {
    let vk_safe_bytes = unpack_vk_bytes(ctx, range, vk_bytes);

    let zero = ctx.load_zero();

    let hi_bytes = uint_to_bytes_be(ctx, range, &zero, 16);

    let mut vk_keccak_safe_bytes: Vec<SafeByte<F>> = vec![];

    // convert back to hilo be bytes
    vk_safe_bytes.chunks(16).for_each(|chunk| {
        let mut reversed_chunk = chunk.to_vec();
        reversed_chunk.reverse();
        vk_keccak_safe_bytes.extend(hi_bytes.clone());
        vk_keccak_safe_bytes.extend(reversed_chunk);
    });

    let vk_keccak_input = FixLenBytesVec::<F>::new(vk_keccak_safe_bytes, (NUM_BYTES_VK - 1) * 2);
    let vk_keccak_subquery: KeccakFixLenCall<F> = KeccakFixLenCall::new(vk_keccak_input);

    subquery_caller
        .lock()
        .unwrap()
        .keccak(ctx, vk_keccak_subquery)
}

// unpack vk_bytes to flattened SafeBytes, where every 16 SafeBytes being the little endian of one vk point lo
// the vk_bytes is in chunks (13 vk_bytes per chunk), for the first vk_byte of each chunk, the most significant
// byte of the bytes32 contains null_chunk flag, which is not part of the vk
// each of the vk_byte is from 31 (or NUM_BYTES_VK % 31) little endian bytes
// the bytes array was appended with num_inputs at the end, which is not part of vk
pub fn unpack_vk_bytes<F: Field>(
    ctx: &mut Context<F>,
    range: &RangeChip<F>,
    vk_bytes: &Vec<AssignedValue<F>>,
) -> Vec<SafeByte<F>> {
    let mut idx = 0;
    let mut num_bytes: usize = NUM_BYTES_VK;
    let mut vk_safe_bytes: Vec<SafeByte<F>> = vec![];

    while num_bytes > 0 {
        let num_bytes_fe = min(NUM_BYTES_PER_FE, num_bytes);
        let vk_byte: AssignedValue<F> = vk_bytes[idx];
        let num_bytes_uint = if idx % NUM_FE_PER_CHUNK == 0 {
            // For the first fe of each chunk (13 FE), the most significant byte contains null_chunk flag
            32
        } else {
            num_bytes_fe
        };
        let mut chunk_bytes = uint_to_bytes_le(ctx, range, &vk_byte, num_bytes_uint);

        if idx % NUM_FE_PER_CHUNK == 0 {
            let res = chunk_bytes[31];

            range
                .gate()
                .assert_is_const(ctx, &res, &F::from(NULL_CHUNK_VAL as u64));
            chunk_bytes = chunk_bytes[0..31].to_vec();
        }

        vk_safe_bytes.append(&mut chunk_bytes);
        num_bytes -= num_bytes_fe;
        idx += 1;
    }

    assert_eq!(vk_safe_bytes.len(), NUM_BYTES_VK);

    let num_inputs = vk_safe_bytes.pop().unwrap();
    range
        .gate()
        .assert_is_const(ctx, &num_inputs, &F::from((MAX_GROTH16_PI + 1) as u64));

    vk_safe_bytes
}

pub fn get_signal_hash<P: JsonRpcClient, F: Field>(
    ctx: &mut Context<F>,
    range: &RangeChip<F>,
    subquery_caller: &Arc<Mutex<SubqueryCaller<P, F>>>,
    receiver: &AssignedValue<F>,
) -> AssignedValue<F> {
    let receiver_safe_bytes = uint_to_bytes_be(ctx, range, receiver, 20);
    let receiver_keccak_input = FixLenBytesVec::<F>::new(receiver_safe_bytes, 20);
    let receiver_keccak_subquery = KeccakFixLenCall::new(receiver_keccak_input);
    let receiver_keccak = subquery_caller
        .lock()
        .unwrap()
        .keccak(ctx, receiver_keccak_subquery);

    // signal_hash is keccak(receiver) >> 8. since keccak(receiver) result is hilo
    // signal_hash_hi = keccak_result_hi >> 8
    // signal_hash_lo = keccak_result_lo >> 8 + (keccak_result_hi_remainder << 16 * 8) >> 8
    let shift = ctx.load_constant(biguint_to_fe(&BigUint::from(2u64).pow((16 - 1) * 8)));
    let (signal_hash_hi, signal_hash_hi_res) =
        range.div_mod(ctx, receiver_keccak.hi(), 256u64, 128);
    let (signal_hash_lo_div, _) = range.div_mod(ctx, receiver_keccak.lo(), 256u64, 128);

    let signal_hash_lo = range
        .gate()
        .mul_add(ctx, signal_hash_hi_res, shift, signal_hash_lo_div);
    from_hi_lo(
        ctx,
        range,
        HiLo::from_hi_lo([signal_hash_hi, signal_hash_lo]),
    )
}
