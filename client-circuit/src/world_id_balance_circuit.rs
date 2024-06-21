use crate::types::WorldcoinInput;
use crate::{constants::*, types::WorldcoinInputCoreParams};
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

use axiom_eth::utils::uint_to_bytes_be;

use axiom_circuit::subquery::types::ECDSAComponentInput;
use axiom_eth::keccak::promise::KeccakFixLenCall;
use axiom_eth::Field;
use ethers::utils::keccak256;

use axiom_sdk::{
    halo2_base::{
        gates::{GateInstructions, RangeChip, RangeInstructions},
        safe_types::{FixLenBytesVec, SafeByte, SafeTypeChip},
        utils::ScalarField,
        AssignedValue, Context,
    },
    subquery::account::Account,
    HiLo,
};

use halo2curves::ff::PrimeField;

// use axiom_query::axiom_eth::{
//     halo2_base::{
//         gates::{GateInstructions, RangeChip, RangeInstructions},
//         safe_types::SafeTypeChip,
//         AssignedValue, Context,
//         QuantumCell::Constant,
//     },
//     keccak::promise::KeccakFixLenCall,
//     utils::{hilo::HiLo, uint_to_bytes_be},
// };

use crate::utils::{get_signal_hash, get_vk_hash};
use crate::world_id_balance_types::*;
use axiom_circuit::subquery::types::AssignedAccountSubquery;
use axiom_sdk::subquery::{self, AccountField};

#[derive(Debug, Clone, Default)]
pub struct WorldIdBalanceCircuit;

impl<P: JsonRpcClient, F: Field> AxiomCircuitScaffold<P, F> for WorldIdBalanceCircuit {
    type InputValue = WorldIdBalanceInput<F>;
    type InputWitness = WorldIdBalanceInput<AssignedValue<F>>;
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
        callback.push(to_hi_lo(ctx, range, assigned_inputs.num_proofs));

        let mut receiver_vec: Vec<HiLo<AssignedValue<F>>> = Vec::new();
        let mut nullifier_hash_vec: Vec<HiLo<AssignedValue<F>>> = Vec::new();

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

            receiver_vec.push(to_hi_lo(ctx, range, receiver));
            nullifier_hash_vec.push(to_hi_lo(ctx, range, public_inputs[1]));
        }

        callback.append(&mut receiver_vec);
        callback.append(&mut nullifier_hash_vec);

        verify_signatures(
            ctx,
            range,
            &assigned_inputs.pubkeys,
            &assigned_inputs.message_hash,
            &subquery_caller,
            &assigned_inputs.signatures,
            &assigned_inputs.receivers,
        );
        let addrs: Vec<AssignedValue<F>> = assigned_inputs
            .pubkeys
            .iter()
            .map(|p| get_addr_from_pubkey(ctx, range, &subquery_caller, *p))
            .collect();
        for i in 0..addrs.len() {
            ctx.constrain_equal(&addrs[i], &assigned_inputs.receivers[i]);
        }

        let field_constant = ctx.load_constant(F::from(AccountField::Balance as u64));
        let subquery = AssignedAccountSubquery {
            block_number: assigned_inputs.block_number,
            addr: assigned_inputs.receivers[0],
            field_idx: field_constant,
        };

        let balance_at_block = subquery_caller.lock().unwrap().call(ctx, subquery);
        let balance_at_block = from_hi_lo(ctx, range, balance_at_block);
        let one_ether = F::from(10u64.pow(18));
        let one_ether = ctx.load_constant(one_ether);
        range.check_less_than(ctx, one_ether, balance_at_block, 87);
    }
}

pub fn get_addr_from_pubkey<F: Field + ScalarField, P: JsonRpcClient>(
    ctx: &mut Context<F>,
    range: &RangeChip<F>,
    subquery_caller: &Arc<Mutex<SubqueryCaller<P, F>>>,
    pubkey: (HiLo<AssignedValue<F>>, HiLo<AssignedValue<F>>),
) -> AssignedValue<F> {
    // Combine bytes to make the encode(Data) portion of the message
    let mut input = Vec::new();
    let mut x_hi_bytes = uint_to_bytes_be(ctx, range, &pubkey.0.hi(), 16);
    let mut x_lo_bytes = uint_to_bytes_be(ctx, range, &pubkey.0.lo(), 16);
    let mut y_hi_bytes = uint_to_bytes_be(ctx, range, &pubkey.1.hi(), 16);
    let mut y_lo_bytes = uint_to_bytes_be(ctx, range, &pubkey.1.lo(), 16);
    input.append(&mut x_hi_bytes);
    input.append(&mut x_lo_bytes);
    input.append(&mut y_hi_bytes);
    input.append(&mut y_lo_bytes);
    let input = FixLenBytesVec::new(input, 64);
    let subquery = KeccakFixLenCall::new(input);
    let ans_hilo = subquery_caller.lock().unwrap().keccak(ctx, subquery);
    let mut modulus = F::from(1 << 32);
    modulus = modulus * modulus;
    modulus = modulus * modulus;
    let pow32 = F::from(1 << 32);
    let modulus = ctx.load_constant(modulus);
    let pow32 = ctx.load_constant(pow32);
    let bottom_bytes = range.div_mod_var(ctx, ans_hilo.hi(), pow32, 128, 33).1;
    let addr = range
        .gate()
        .mul_add(ctx, bottom_bytes, modulus, ans_hilo.lo());
    addr
}

pub fn verify_signatures<P: JsonRpcClient, F: Field>(
    ctx: &mut Context<F>,
    range: &RangeChip<F>,
    pubkeys: &Vec<(HiLo<AssignedValue<F>>, HiLo<AssignedValue<F>>)>,
    message_hash: &HiLo<AssignedValue<F>>,
    subquery_caller: &Arc<Mutex<SubqueryCaller<P, F>>>,
    signatures: &Vec<Signature<AssignedValue<F>>>,
    receivers: &Vec<AssignedValue<F>>,
) {
    let safe = SafeTypeChip::new(range);
    let zero = ctx.load_constant(F::ZERO);
    let one = ctx.load_constant(F::ONE);
    let zero = SafeTypeChip::<'_, F>::unsafe_to_byte(zero);

    // verify signatures
    for i in 0..signatures.len() {
        let sig = signatures[i].clone();
        let pubkey = pubkeys[i];
        // println!("MSG IS {:?}", msg);
        let subquery = ECDSAComponentInput {
            pubkey,
            r: sig.r,
            s: sig.s,
            msg_hash: message_hash.clone(),
        };

        let result = subquery_caller.lock().unwrap().call(ctx, subquery);
        ctx.constrain_equal(&result.lo(), &one);
    }
    // I MUST VERIFY PUBKEY AGAINST ADDRESS
}
