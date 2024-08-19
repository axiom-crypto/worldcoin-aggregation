use std::iter;

use axiom_eth::{
    halo2_base::{
        gates::{flex_gate::threads::parallelize_core, GateInstructions, RangeInstructions},
        utils::biguint_to_fe,
        AssignedValue, Context,
    },
    halo2curves::bn256::Fr,
    mpt::MPTChip,
    rlc::circuit::builder::RlcCircuitBuilder,
    utils::{
        build_utils::aggregation::CircuitMetadata, encode_addr_to_field,
        eth_circuit::EthCircuitInstructions, hilo::HiLo, keccak::decorator::RlcKeccakCircuitImpl,
    },
    Field,
};

use ethers::types::Address;
use itertools::Itertools;
use std::str::FromStr;

use axiom_components::{
    groth16::{
        get_groth16_consts_from_max_pi, handle_single_groth16verify,
        test::parse_input,
        types::{
            Groth16VerifierComponentProof, Groth16VerifierComponentVerificationKey,
            Groth16VerifierInput,
        },
    },
    utils::flatten::InputFlatten,
};
use num_bigint::BigUint;

use std::{fmt::Debug, vec};

use crate::{circuit_factory::leaf::WorldcoinRequestLeaf, constants::*};
use crate::{
    types::*,
    utils::{get_signal_hash, get_vk_hash},
};

pub type WorldcoinLeafCircuit<F> = RlcKeccakCircuitImpl<F, WorldcoinLeafInput<F>>;

#[derive(Clone, Debug, Default)]
pub struct WorldcoinLeafInput<T: Copy> {
    pub root: T,
    pub grant_id: T,
    pub start: u32,
    pub end: u32,
    pub receivers: Vec<T>,
    pub groth16_inputs: Vec<Groth16VerifierInput<T>>,
    pub max_depth: usize,
}

impl WorldcoinLeafInput<Fr> {
    pub fn new(
        vk_str: String,
        root: String,
        grant_id: String,
        start: u32,
        end: u32,
        max_depth: usize,
        claims: Vec<ClaimNative>,
    ) -> Self {
        let num_proofs = (end - start) as usize;
        assert!(claims.len() == num_proofs);
        assert!(num_proofs > 0);
        let max_proofs: usize = 1 << max_depth;

        let mut pf_strings: Vec<String> = Vec::new();
        let mut pub_strings: Vec<String> = Vec::new();
        let mut receivers: Vec<Fr> = Vec::new();
        let mut receivers_native: Vec<Address> = Vec::new();

        for _i in 0..num_proofs {
            let pf_string = get_pf_string(&claims[_i].proof);
            let pub_string = get_pub_string(
                &root,
                &grant_id,
                &claims[_i].nullifier_hash,
                &claims[_i].receiver,
            );
            pf_strings.push(pf_string);
            pub_strings.push(pub_string);
            receivers_native.push(claims[_i].receiver);
        }

        pf_strings.resize(max_proofs, pf_strings[0].clone());
        pub_strings.resize(max_proofs, pub_strings[0].clone());
        receivers_native.resize(max_proofs, receivers_native[0].clone());

        let mut groth16_inputs: Vec<Groth16VerifierInput<Fr>> = Vec::new();

        // Currently vk parsing is coupled with pf and pub, we should refactor
        // to have a separate function for parsing vk
        for _i in 0..max_proofs {
            let groth16_input: Groth16VerifierInput<Fr> = parse_input(
                vk_str.clone(),
                pf_strings[_i].clone(),
                pub_strings[_i].clone(),
                MAX_GROTH16_PI,
            );

            groth16_inputs.push(groth16_input);

            let receiver_fe = encode_addr_to_field(&receivers_native[_i]);
            receivers.push(receiver_fe);
        }

        let root_fe = biguint_to_fe(&BigUint::from_str(root.as_str()).unwrap());

        let grant_id_fe = biguint_to_fe(&BigUint::from_str(grant_id.as_str()).unwrap());

        Self {
            root: root_fe,
            grant_id: grant_id_fe,
            receivers,
            start,
            end,
            max_depth,
            groth16_inputs,
        }
    }
}

impl From<WorldcoinRequestLeaf> for WorldcoinLeafInput<Fr> {
    fn from(input: WorldcoinRequestLeaf) -> Self {
        let WorldcoinRequestLeaf {
            vk,
            root,
            grant_id,
            start,
            end,
            depth,
            claims,
        } = input;
        let vk_str = serde_json::to_string(&vk).unwrap();
        WorldcoinLeafInput::new(vk_str, root, grant_id, start, end, depth, claims)
    }
}

impl<F: Field> WorldcoinLeafInput<F> {
    pub fn assign(&self, ctx: &mut Context<F>) -> WorldcoinAssignedInput<F> {
        let start = ctx.load_witness(F::from(self.start as u64));

        let end = ctx.load_witness(F::from(self.end as u64));
        let root = ctx.load_witness(self.root);
        let grant_id = ctx.load_witness(self.grant_id);

        // receivers and groth16_inputs should have the same length
        assert_eq!(self.receivers.len(), self.groth16_inputs.len());

        let receivers = ctx.assign_witnesses(self.receivers.clone());

        let mut groth16_verifier_inputs: Vec<Groth16VerifierInput<AssignedValue<F>>> = Vec::new();
        let num_public_inputs = ctx.load_witness(F::from(MAX_GROTH16_PI as u64 + 1));
        let constants = get_groth16_consts_from_max_pi(MAX_GROTH16_PI);

        for groth16_input in self.groth16_inputs.iter() {
            let input: Groth16Input<F> = groth16_input.clone().into();
            let vk = ctx.assign_witnesses(input.vkey_bytes);
            let proof = ctx.assign_witnesses(input.proof_bytes);
            let public_inputs = ctx.assign_witnesses(input.public_inputs);

            let groth16_verifier_input: Groth16VerifierInput<AssignedValue<F>> =
                Groth16VerifierInput {
                    vk: Groth16VerifierComponentVerificationKey::unflatten(
                        vk,
                        constants.gamma_abc_g1_len,
                    ),
                    proof: Groth16VerifierComponentProof::unflatten(proof).unwrap(),
                    public_inputs,
                    num_public_inputs,
                };

            groth16_verifier_inputs.push(groth16_verifier_input);
        }

        WorldcoinAssignedInput {
            start,
            end,
            root,
            grant_id,
            receivers,
            groth16_verifier_inputs,
        }
    }
}

/// Data passed from phase0 to phase1
/// instances:
/// [0] start
/// [1] end
/// [2, 4) vkey_hash
/// [4] grant_id
/// [5] root
/// [6, 6 + 1 << max_depth) receiver_i
/// [6 + 1 << max_depth, 6 + 2 * (1 << max_depth)) nullifier_hash_i
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

impl<F: Field> CircuitMetadata for WorldcoinLeafInput<F> {
    const HAS_ACCUMULATOR: bool = false;
    fn num_instance(&self) -> Vec<usize> {
        vec![6 + 2 * (1 << self.max_depth)]
    }
}

impl<F: Field> EthCircuitInstructions<F> for WorldcoinLeafInput<F> {
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
        let WorldcoinAssignedInput {
            start,
            end,
            root,
            grant_id,
            receivers,
            groth16_verifier_inputs,
        } = self.assign(ctx);

        // ==== Constraints ====

        // 0 <= start < end < 2^253
        range.range_check(ctx, start, 253);
        range.range_check(ctx, end, 253);
        range.check_less_than(ctx, start, end, 253);

        let num_proofs = range.gate().sub(ctx, end, start);
        let max_proofs = ctx.load_witness(F::from(1 << self.max_depth));
        let max_proofs_plus_one = range.gate().add(ctx, max_proofs, one);

        // constrain 0 < num_proofs <= max_proofs
        range.check_less_than(ctx, zero, num_proofs, 64);
        range.check_less_than(ctx, num_proofs, max_proofs_plus_one, 64);

        let constants = get_groth16_consts_from_max_pi(MAX_GROTH16_PI);
        let vk_bytes: Vec<AssignedValue<F>> = groth16_verifier_inputs[0].vk.flatten();

        assert_eq!(vk_bytes.len(), constants.num_fe_hilo_vkey);

        let vk_hash: HiLo<AssignedValue<F>> = get_vk_hash(ctx, range, keccak, vk_bytes.clone());

        // Vec<Groth16VerifierInput, receiver>
        let inputs: Vec<(Groth16VerifierInput<AssignedValue<F>>, &AssignedValue<F>)> =
            groth16_verifier_inputs
                .into_iter()
                .zip(&receivers)
                .collect_vec();

        let nullifier_hashes = parallelize_core(builder.base.pool(0), inputs, |ctx, input| {
            let (groth16_verifier_input, receiver) = input;

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

            // nullifier_hash
            public_inputs[1]
        });

        let assigned_instances = iter::empty()
            .chain([start, end])
            .chain([vk_hash.hi(), vk_hash.lo()])
            .chain([grant_id, root])
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
        _builder: &mut RlcCircuitBuilder<F>,
        _mpt: &MPTChip<F>,
        _witness: Self::FirstPhasePayload,
    ) {
        // do nothing
    }
}
