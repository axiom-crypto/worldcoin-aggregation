use crate::constants::*;
use crate::types::WorldcoinInput;
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
use axiom_eth::{keccak::promise::KeccakFixLenCall, utils::uint_to_bytes_be, Field};

use axiom_sdk::{
    halo2_base::{
        gates::{RangeChip, RangeInstructions},
        safe_types::FixLenBytesVec,
        safe_types::SafeTypeChip,
        AssignedValue,
    },
    HiLo,
};

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

        // vkey_bytes
        //     .iter()
        //     .for_each(|v| callback.push(to_hi_lo(ctx, range, *v)));

        let safe = SafeTypeChip::new(range);

        let input = safe.raw_to_fix_len_bytes_vec(ctx, vkey_bytes.clone(), NUM_FE_VKEY);
        let keccak_subquery = KeccakFixLenCall::new(input);
        let vkey_hash = subquery_caller.lock().unwrap().keccak(ctx, keccak_subquery);

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
            ctx.constrain_equal(&verify, &one);

            signal_hash_vec.push(to_hi_lo(ctx, range, public_inputs[2]));
            nullifier_hash_vec.push(to_hi_lo(ctx, range, public_inputs[1]));
        }

        callback.append(&mut signal_hash_vec);
        callback.append(&mut nullifier_hash_vec);
    }
}
