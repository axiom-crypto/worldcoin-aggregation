use std::{fmt::Debug, vec};

use axiom_circuit::subquery::groth16::{assign_groth16_input_with_known_vk, parse_groth16_input};
use axiom_sdk::{
    axiom::{AxiomAPI, AxiomComputeFn, AxiomComputeInput, AxiomResult},
    cmd::run_cli,
    halo2_base::{gates::RangeInstructions, utils::biguint_to_fe, AssignedValue},
    Fr,
};
use ethers::utils::keccak256;
use ethers::{abi::Address, types::U256};
use num_bigint::BigUint;
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::str::FromStr;

#[AxiomComputeInput]
pub struct Groth16ClientInput {
    pub dummy: u64,
}

const MAX_PROOFS: usize = 16;
const MAX_GROTH16_PI: usize = 4;

#[derive(Debug, Deserialize, Serialize)]
struct Claim {
    receiver: String,
    nullifier_hash: String,
    proof: Vec<String>,
}

#[derive(Debug, Deserialize, Serialize)]
struct WorldcoinInput {
    root: String,
    grant_id: String,
    num_proofs: usize,
    claims: Vec<Claim>,
}

fn get_pf_string(proof: &[String]) -> String {
    json!({
        "pi_a": [proof[0], proof[1], "1"],
        // Note proof[2] and proof[3] are swapped
        // https://github.com/worldcoin/world-id-contracts/blob/4efbd67ed28753bb13985bc2312a450b18f50e1b/src/SemaphoreVerifier.sol#L474
        // https://github.com/axiom-crypto/semaphore-rs/blob/496bf21829fbc4e22ef5f2d566ae88a2b586a17f/src/protocol/mod.rs#L75
        "pi_b": [[proof[3], proof[2]], [proof[5], proof[4]], ["1", "0"]],
        "pi_c": [proof[6], proof[7], "1"],
        "protocol": "groth16",
        "curve": "bn128"
    })
    .to_string()
}

fn get_pub_string(root: &str, grant_id: &str, claim: &Claim) -> String {
    let signal_hash = get_signal_hash(&claim.receiver).to_string();
    json!([root, claim.nullifier_hash, signal_hash, grant_id]).to_string()
}

impl AxiomComputeFn for Groth16ClientInput {
    fn compute(
        api: &mut AxiomAPI,
        _: Groth16ClientCircuitInput<AssignedValue<Fr>>,
    ) -> Vec<AxiomResult> {
        let zero = api.ctx().load_zero();
        let one = api.ctx().load_constant(Fr::one());

        let vk_string = include_str!("../data/vk.json").to_string();

        let input_json_str: &str = include_str!("../data/worldcoin_input.json");
        // https://optimistic.etherscan.io/tx/0x857068d4fbc4434b11e49bcbeb3663ba2b3b89770a5d20203bf206ff0645f104
        // https://optimistic.etherscan.io/tx/0xe5ae2511577a857b34efa8a1795f47b875d2885b1b8855775c4d409ae52a9a2b
        let worldcoin_input: WorldcoinInput = serde_json::from_str(input_json_str).unwrap();
        assert!(worldcoin_input.claims.len() == worldcoin_input.num_proofs);

        let num_proofs = worldcoin_input.num_proofs;
        let assigned_num_proofs = api.ctx().load_witness(Fr::from(num_proofs as u64));

        api.range
            .check_less_than(api.ctx(), zero, assigned_num_proofs, 64);

        let max_proofs = api.ctx().load_constant(Fr::from(MAX_PROOFS as u64));
        api.range
            .check_less_than(api.ctx(), assigned_num_proofs, max_proofs, 64);

        let mut return_vec: Vec<AxiomResult> = Vec::new();

        let root = worldcoin_input.root;
        let grant_id = worldcoin_input.grant_id;

        let mut pf_strings: Vec<String> = Vec::new();
        let mut pub_strings: Vec<String> = Vec::new();

        for _i in 0..num_proofs {
            let pf_string = get_pf_string(&worldcoin_input.claims[_i].proof);
            let pub_string = get_pub_string(&root, &grant_id, &worldcoin_input.claims[_i]);
            pf_strings.push(pf_string);
            pub_strings.push(pub_string);
        }

        pf_strings.resize(MAX_PROOFS, pf_strings[0].clone());
        pub_strings.resize(MAX_PROOFS, pub_strings[0].clone());

        // Currently vk parsing is coupled with pf and pub, we should refactor
        // to have a separate function for parsing vk
        let groth16_input = parse_groth16_input(
            vk_string.clone(),
            pf_strings[0].clone(),
            pub_strings[0].clone(),
            MAX_GROTH16_PI,
        );

        let assigned_vkey = groth16_input
            .vkey_bytes
            .iter()
            .map(|v| api.ctx().load_witness(*v))
            .collect::<Vec<_>>();

        let grant_id_fe = biguint_to_fe(&BigUint::from_str(&grant_id).unwrap());
        let assigned_grant_id = api.ctx().load_witness(grant_id_fe);
        let root_fe = biguint_to_fe(&BigUint::from_str(&root).unwrap());
        let assigned_root = api.ctx().load_witness(root_fe);

        assigned_vkey
            .iter()
            .for_each(|v| return_vec.push((*v).into()));
        return_vec.push(assigned_grant_id.into());
        return_vec.push(assigned_root.into());
        return_vec.push(assigned_num_proofs.into());

        for i in 0..MAX_PROOFS {
            let groth16_input = parse_groth16_input(
                vk_string.clone(),
                pf_strings[i].clone(),
                pub_strings[i].clone(),
                MAX_GROTH16_PI,
            );
            let assigned_input = assign_groth16_input_with_known_vk(
                api.ctx(),
                assigned_vkey.clone(),
                groth16_input.proof_bytes,
                groth16_input.public_inputs,
            );

            let public_inputs = assigned_input.public_inputs.clone();

            api.ctx()
                .constrain_equal(&public_inputs[3], &assigned_grant_id.into());
            api.ctx()
                .constrain_equal(&public_inputs[0], &&assigned_root.into());

            let verify = api.groth16_verify(assigned_input);
            let verify = api.from_hi_lo(verify);
            api.ctx().constrain_equal(&verify, &one);

            return_vec.push(public_inputs[1].into());
            return_vec.push(public_inputs[2].into());
        }

        return_vec
    }
}

// Return signal hash given receiver address
// https://github.com/worldcoin/worldcoin-grants-contracts/blob/41cdb2a5d0ceb5be06da078ed35c5937d4f30445/src/RecurringGrantDrop.sol#L255
fn get_signal_hash(receiver: &str) -> U256 {
    // solidity:  uint256(keccak256(abi.encodePacked(receiver))) >> 8
    let receiver_address: Address = Address::from_str(receiver).unwrap();
    let receiver_bytes = receiver_address.as_bytes();
    let keccak_hash = keccak256(receiver_bytes);
    let uint256_value = u256_from_bytes_be(&keccak_hash);
    uint256_value >> 8
}

fn u256_from_bytes_be(bytes: &[u8]) -> ethers::types::U256 {
    let mut array = [0u8; 32];
    array[(32 - bytes.len())..].copy_from_slice(bytes);
    ethers::types::U256::from_big_endian(&array)
}

fn main() {
    run_cli::<Groth16ClientInput>();
}
