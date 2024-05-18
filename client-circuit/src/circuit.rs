use crate::constants::*;
use crate::types::WorldcoinInput;
use ethers::providers::JsonRpcClient;
use std::{
    fmt::Debug,
    process::id,
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
    zkevm_hashes::keccak::vanilla::util::unpack,
    Field,
};

use axiom_sdk::{
    halo2_base::{
        gates::GateInstructions,
        gates::{RangeChip, RangeInstructions},
        safe_types::FixLenBytesVec,
        safe_types::SafeByte,
        safe_types::SafeTypeChip,
        utils::biguint_to_fe,
        AssignedValue,
    },
    HiLo,
};

use num_bigint::BigUint;
use std::cmp::min;

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

        let mut verification_result: AssignedValue<F> = ctx.load_constant(F::ZERO);

        let mut bytes: Vec<SafeByte<F>> = vec![];

        let mut idx = 0;

        let shift = ctx.load_constant(biguint_to_fe(&BigUint::from(2u64).pow(31 * 8)));

        /**
            *   let packed_fe_with_res = packed_fe
           .chunks(NUM_FE_PER_CHUNK)
           .collect::<Vec<_>>()
           .iter()
           .enumerate()
           .flat_map(|(idx, x)| {
               let mut bytes = x.to_vec();
               let mut arr: [u8; 32] = [0; 32];
               if idx == constants.num_chunks - 1 {
                   arr[31] = res as u8;
                   bytes[0] += F::from_bytes_le(&arr);
               } else {
                   arr[31] = 2;
                   bytes[0] += F::from_bytes_le(&arr);
               }
               bytes
           })
           .collect::<Vec<_>>();



        let mut input = input
           .chunks(NUM_FE_PER_CHUNK)
           .collect::<Vec<_>>()
           .iter()
           .flat_map(|x| {
               let mut x = x.to_vec();
               let first_fe_bytes = x[0].to_bytes_le();
               x[0] = F::from_bytes_le(&first_fe_bytes[..31]);
               x
           })
           .collect::<Vec<_>>();
            */
        let mut unpack_bytes = |bytes: &mut Vec<SafeByte<F>>, mut num_bytes: usize| {
            while num_bytes > 0 {
                println!("{}", idx);
                let num_bytes_fe = min(31, num_bytes);
                let value = &assigned_inputs.groth16_inputs[0].vkey_bytes[idx];
                println!("{:?}", value);

                let uint_bytes = if idx % 13 == 0 { 32 } else { num_bytes_fe };
                let mut chunk_bytes = uint_to_bytes_le(ctx, range, value, uint_bytes);

                if idx % 13 == 0 {
                    chunk_bytes = chunk_bytes[1..=31].to_vec();
                    // TODO: constrain the first byte value
                }
                bytes.append(&mut chunk_bytes);

                num_bytes -= num_bytes_fe;
                idx += 1;
            }
        };

        unpack_bytes(&mut bytes, NUM_BYTES_VK);

        assert_eq!(bytes.len(), NUM_BYTES_VK);
        let num_inputs = bytes.pop().unwrap();

        let safe = SafeTypeChip::new(range);

        println!("bytes ===== {:?}", bytes);

        let hi_bytes = uint_to_bytes_be(ctx, range, &zero, 16);

        let mut bytes_be: Vec<SafeByte<F>> = vec![];
        bytes.chunks(16).for_each(|chunk| {
            let mut reversed_chunk = chunk.to_vec();
            reversed_chunk.reverse();
            bytes_be.extend(hi_bytes.clone());
            bytes_be.extend(reversed_chunk);
        });

        println!("bytes be ===== {:?}", bytes_be);
        println!("bytes be len {:?}", bytes_be.len());

        let input = FixLenBytesVec::<F>::new(bytes_be, (NUM_BYTES_VK - 1) * 2);

        let keccak_subquery = KeccakFixLenCall::new(input);
        let vkey_hash = subquery_caller.lock().unwrap().keccak(ctx, keccak_subquery);

        println!("vkey_hash {:?}", vkey_hash);
        callback.push(vkey_hash);
        callback.push(to_hi_lo(ctx, range, assigned_inputs.grant_id));
        callback.push(to_hi_lo(ctx, range, assigned_inputs.root));
        callback.push(to_hi_lo(ctx, range, assigned_inputs.num_proofs));

        let mut signal_hash_vec: Vec<HiLo<AssignedValue<F>>> = Vec::new();
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
            // ctx.constrain_equal(&verify, &one);

            signal_hash_vec.push(to_hi_lo(ctx, range, public_inputs[2]));
            nullifier_hash_vec.push(to_hi_lo(ctx, range, public_inputs[1]));
        }

        callback.append(&mut signal_hash_vec);
        callback.append(&mut nullifier_hash_vec);
    }
}
