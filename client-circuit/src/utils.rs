use crate::constants::*;
use axiom_components::groth16::{NULL_CHUNK_VAL, NUM_BYTES_PER_FE, NUM_FE_PER_CHUNK};
use ethers::providers::JsonRpcClient;
use std::sync::{Arc, Mutex};

use axiom_circuit::subquery::caller::SubqueryCaller;

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
        QuantumCell::Constant,
    },
    HiLo,
};

use std::cmp::min;

use num_bigint::BigUint;

pub fn get_vk_hash<P: JsonRpcClient, F: Field>(
    ctx: &mut Context<F>,
    range: &RangeChip<F>,
    subquery_caller: &Arc<Mutex<SubqueryCaller<P, F>>>,
    vk_bytes: &Vec<AssignedValue<F>>,
) -> HiLo<AssignedValue<F>> {
    let vk_hilo_be_bytes: Vec<SafeByte<F>> = unpack_vk_bytes(ctx, range, vk_bytes);
    let vk_keccak_input = FixLenBytesVec::<F>::new(vk_hilo_be_bytes, (NUM_BYTES_VK - 1) * 2);
    let vk_keccak_subquery: KeccakFixLenCall<F> = KeccakFixLenCall::new(vk_keccak_input);

    subquery_caller
        .lock()
        .unwrap()
        .keccak(ctx, vk_keccak_subquery)
}

// unpack vk_bytes to flattened SafeBytes, where every 32 SafeBytes represents the big endian of one HiLo point
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

    let zero = ctx.load_zero();
    let hi_bytes: Vec<SafeByte<F>> = uint_to_bytes_be(ctx, range, &zero, 16);

    let mut vk_hilo_be_bytes: Vec<SafeByte<F>> = vec![];

    // convert back to hilo be bytes
    vk_safe_bytes.chunks(16).for_each(|chunk| {
        let mut reversed_chunk = chunk.to_vec();
        reversed_chunk.reverse();
        vk_hilo_be_bytes.extend(hi_bytes.clone());
        vk_hilo_be_bytes.extend(reversed_chunk);
    });
    vk_hilo_be_bytes
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

    range.gate.mul_add(
        ctx,
        signal_hash_hi,
        Constant(range.gate.pow_of_two()[128]),
        signal_hash_lo,
    )
}
