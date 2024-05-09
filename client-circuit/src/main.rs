use std::{fmt::Debug, vec};

use axiom_circuit::subquery::groth16::{parse_groth16_input, Groth16Input};
use axiom_sdk::{
    axiom::{AxiomAPI, AxiomComputeFn, AxiomComputeInput, AxiomResult},
    cmd::run_cli,
    halo2_base::{gates::RangeInstructions, AssignedValue},
    subquery::groth16::assign_groth16_input_with_known_vk,
    Fr,
};
use ethers::utils::keccak256;
use ethers::{abi::Address, types::U256};
use serde_json::{json, Value};
use std::str::FromStr;

// Return signal hash given receiver address
// https://github.com/worldcoin/worldcoin-grants-contracts/blob/41cdb2a5d0ceb5be06da078ed35c5937d4f30445/src/RecurringGrantDrop.sol#L255
fn get_signal_hash(receiver: &str) -> U256 {
    // solidity:  uint256(keccak256(abi.encodePacked(receiver))) >> 8
    let receiver_address: Address = Address::from_str(receiver).unwrap();
    let receiver_bytes = receiver_address.as_bytes();
    let keccak_hash = keccak256(receiver_bytes);
    let uint256_value = u256_from_bytes_be(&keccak_hash);
    let result = uint256_value >> 8;

    result
}

fn u256_from_bytes_be(bytes: &[u8]) -> ethers::types::U256 {
    let mut array = [0u8; 32];
    array[(32 - bytes.len())..].copy_from_slice(bytes);
    ethers::types::U256::from_big_endian(&array)
}

#[AxiomComputeInput]
pub struct Groth16ClientInput {
    pub dummy: u64,
}

const MAX_PROOFS: usize = 16;
const MAX_GROTH16_PI: usize = 4;

pub fn parse_worldcoin_input() -> Groth16Input<Fr> {
    let vk_string: String = include_str!("../data/vk.json").to_string();
    // https://optimistic.etherscan.io/tx/0xe25692ba505a3c7c9bae0e5cf4e48fe8ae2192933a8f93311e7f2401619f0a66
    let input_json_str: &str = include_str!("../data/worldcoin_input.json");

    let input_json: Value = serde_json::from_str(input_json_str).unwrap();

    let root = &input_json["root"];
    let grant_id = &input_json["grant_id"];
    let claims = &input_json["claims"];
    let receiver: &Value = &claims[0]["receiver"];
    let nullifier_hash = &claims[0]["nullifier_hash"];
    let signal_hash = get_signal_hash(receiver.as_str().unwrap()).to_string();
    let public_input_json = json!([root, nullifier_hash, signal_hash, grant_id]);

    // root, nullifierHash, signalHash, externalNullifierHash

    let pub_string = serde_json::to_string(&public_input_json).unwrap();
    println!("{}", pub_string);
    let proof = claims[0]["proof"].clone();

    let pf_string = json!({
        "pi_a": [proof[0], proof[1], "1"],
        "pi_b": [[proof[2], proof[3]], [proof[4], proof[5]], ["1", "0"]],
        "pi_c": [proof[6], proof[7], "1"],
        "protocol": "groth16",
        "curve": "bn128"
    })
    .to_string();
    let input = parse_groth16_input(vk_string, pf_string, pub_string, MAX_GROTH16_PI);
    input
}

impl AxiomComputeFn for Groth16ClientInput {
    fn compute(
        api: &mut AxiomAPI,
        _: Groth16ClientCircuitInput<AssignedValue<Fr>>,
    ) -> Vec<AxiomResult> {
        let zero = api.ctx().load_zero();

        let mut return_vec: Vec<AxiomResult> = Vec::new();
        return_vec.reserve(MAX_PROOFS);
        let input = parse_worldcoin_input();

        let assigned_vkey = input
            .vkey_bytes
            .iter()
            .map(|v| api.ctx().load_witness(*v))
            .collect::<Vec<_>>();

        for _i in 1..=MAX_PROOFS {
            // let assigned_input = assign_groth16_input(api, input);
            let assigned_input = assign_groth16_input_with_known_vk(
                api,
                assigned_vkey.clone(),
                input.proof_bytes.clone(),
                input.public_inputs.clone(),
            );
            let public_inputs: Vec<AxiomResult> = assigned_input
                .public_inputs
                .iter()
                .map(|input| (*input).into())
                .collect();

            let [root, nullifier_hash, signal_hash, external_nullifier_hash] =
                public_inputs.try_into().unwrap_or_else(|v: Vec<_>| {
                    panic!("Expected a Vec with a length of 4, but it was {}", v.len())
                });

            let verify = api.groth16_verify(assigned_input);
            let verify = api.from_hi_lo(verify);

            api.range.check_less_than(api.ctx(), zero, verify, 1);
            return_vec.push(nullifier_hash);
            return_vec.push(signal_hash)
        }

        return_vec
    }
}

fn main() {
    run_cli::<Groth16ClientInput>();
}
