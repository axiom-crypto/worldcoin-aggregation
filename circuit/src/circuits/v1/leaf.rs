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
    snark_verifier::util::arithmetic::fe_from_big,
    utils::{
        build_utils::aggregation::CircuitMetadata, encode_addr_to_field,
        eth_circuit::EthCircuitInstructions, hilo::HiLo, keccak::decorator::RlcKeccakCircuitImpl,
    },
    Field,
};

use itertools::{multiunzip, Itertools};
use std::str::FromStr;

use axiom_components::{
    groth16::{
        get_groth16_consts_from_max_pi, handle_single_groth16verify,
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
use crate::{types::*, utils::get_vk_hash};

pub type WorldcoinLeafCircuit<F> = RlcKeccakCircuitImpl<F, WorldcoinLeafInput<F>>;

#[derive(Clone, Debug, Default)]
pub struct WorldcoinLeafInput<T: Copy> {
    pub start: T,
    pub end: T,
    pub vk_bytes: Vec<T>,
    pub root: T,
    pub claims: Vec<ClaimInput<T>>,
    pub num_public_inputs: T,
    pub max_depth: usize,
}

impl WorldcoinLeafInput<Fr> {
    pub fn new(
        vk_str: String,
        root: String,
        start: u32,
        end: u32,
        max_depth: usize,
        claims: Vec<ClaimNative>,
    ) -> Self {
        let num_proofs = (end - start) as usize;
        assert!(claims.len() == num_proofs);
        assert!(num_proofs > 0);
        let max_proofs: usize = 1 << max_depth;
        let vk_bytes = parse_vk(vk_str, MAX_GROTH16_PI);

        let mut claims_input = Vec::new();
        for _i in 0..num_proofs {
            let proof_bytes = parse_proof(get_pf_string(&claims[_i].proof));

            let nullifier_hash =
                fe_from_big(BigUint::from_str(&claims[_i].nullifier_hash).unwrap());
            let receiver = encode_addr_to_field(&claims[_i].receiver);
            let grant_id = fe_from_big(BigUint::from_str(&claims[_i].grant_id).unwrap());
            claims_input.push(ClaimInput {
                receiver,
                nullifier_hash,
                grant_id,
                proof_bytes,
            })
        }
        claims_input.resize(max_proofs, claims_input[0].clone());

        let start = Fr::from(start as u64);
        let end = Fr::from(end as u64);

        let root = biguint_to_fe(&BigUint::from_str(root.as_str()).unwrap());

        let num_public_inputs = Fr::from(MAX_GROTH16_PI as u64 + 1);
        Self {
            root,
            start,
            end,
            max_depth,
            claims: claims_input,
            vk_bytes,
            num_public_inputs,
        }
    }
}

impl From<WorldcoinRequestLeaf> for WorldcoinLeafInput<Fr> {
    fn from(input: WorldcoinRequestLeaf) -> Self {
        let WorldcoinRequestLeaf {
            vk,
            root,
            start,
            end,
            depth,
            claims,
        } = input;
        let vk_str = serde_json::to_string(&vk).unwrap();
        WorldcoinLeafInput::new(vk_str, root, start, end, depth, claims)
    }
}

impl<F: Field> WorldcoinLeafInput<F> {
    pub fn assign(&self, ctx: &mut Context<F>) -> WorldcoinLeafInput<AssignedValue<F>> {
        let start = ctx.load_witness(self.start);
        let end = ctx.load_witness(self.end);
        let root = ctx.load_witness(self.root);
        let num_public_inputs = ctx.load_witness(self.num_public_inputs);

        let mut claim_inputs: Vec<ClaimInput<AssignedValue<F>>> = Vec::new();

        let vk_bytes = ctx.assign_witnesses(self.vk_bytes.clone());

        for claim in self.claims.iter() {
            let proof_bytes = ctx.assign_witnesses(claim.proof_bytes.clone());
            let receiver = ctx.load_witness(claim.receiver);
            let nullifier_hash = ctx.load_witness(claim.nullifier_hash);
            let grant_id = ctx.load_witness(claim.grant_id);

            claim_inputs.push(ClaimInput {
                proof_bytes,
                receiver,
                nullifier_hash,
                grant_id,
            })
        }

        WorldcoinLeafInput::<AssignedValue<F>> {
            start,
            end,
            root,
            vk_bytes,
            claims: claim_inputs,
            num_public_inputs,
            max_depth: self.max_depth,
        }
    }
}

impl<F: Field> CircuitMetadata for WorldcoinLeafInput<F> {
    const HAS_ACCUMULATOR: bool = false;
    fn num_instance(&self) -> Vec<usize> {
        vec![5 + 3 * (1 << self.max_depth)]
    }
}

impl<F: Field> EthCircuitInstructions<F> for WorldcoinLeafInput<F> {
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

        // ==== Assign =====
        let zero = ctx.load_zero();
        let one = ctx.load_constant(F::ONE);
        let WorldcoinLeafInput::<AssignedValue<F>> {
            start,
            end,
            root,
            claims,
            vk_bytes,
            num_public_inputs,
            max_depth,
        } = self.assign(ctx);

        // ==== Constraints ====

        // 0 <= start < end < 2^64
        range.range_check(ctx, start, 64);
        range.range_check(ctx, end, 64);
        range.check_less_than(ctx, start, end, 64);

        let num_proofs = range.gate().sub(ctx, end, start);
        let max_proofs = ctx.load_constant(F::from(1 << max_depth));
        let max_proofs_plus_one = range.gate().add(ctx, max_proofs, one);

        // constrain 0 < num_proofs <= max_proofs
        range.range_check(ctx, num_proofs, 64);
        range.check_less_than(ctx, num_proofs, max_proofs_plus_one, 64);

        let constants = get_groth16_consts_from_max_pi(MAX_GROTH16_PI);

        assert_eq!(self.vk_bytes.len(), constants.num_fe_hilo_vkey);
        let vk_hash: HiLo<AssignedValue<F>> = get_vk_hash(ctx, range, keccak, vk_bytes.clone());
        let vk = Groth16VerifierComponentVerificationKey::unflatten(
            vk_bytes,
            constants.gamma_abc_g1_len,
        );

        parallelize_core(builder.base.pool(0), claims.clone(), |ctx, claim| {
            // pi[0] root
            // pi[1] nullifier_hash
            // pi[2] receiver
            // pi[3] grant_id
            let public_inputs =
                [root, claim.nullifier_hash, claim.receiver, claim.grant_id].to_vec();

            let groth16_verifier_input = Groth16VerifierInput {
                vk: vk.clone(),
                proof: Groth16VerifierComponentProof::unflatten(claim.proof_bytes).unwrap(),
                num_public_inputs,
                public_inputs,
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

            ()
        });

        let (grant_ids, receivers, nullifier_hashes): (
            Vec<AssignedValue<F>>,
            Vec<AssignedValue<F>>,
            Vec<AssignedValue<F>>,
        ) = multiunzip(
            claims
                .into_iter()
                .map(|claim| (claim.grant_id, claim.receiver, claim.nullifier_hash)),
        );

        // instances:
        // [0] start
        // [1] end
        // [2, 3] vkey_hash
        // [4] root
        // [5, 5 + 1 << max_depth) grant_ids_i
        // [5 + 1 << max_depth, 5 + 2 * (1 << max_depth)) receivers_i
        // [5 + 2 * (1 << max_depth), 5 + 3 * (1 << max_depth)) nullifier_hashes_i
        let assigned_instances = iter::empty()
            .chain([start, end])
            .chain([vk_hash.hi(), vk_hash.lo()])
            .chain([root])
            .chain(grant_ids)
            .chain(receivers)
            .chain(nullifier_hashes)
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
