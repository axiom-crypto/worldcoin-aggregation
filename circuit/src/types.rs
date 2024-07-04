use axiom_components::groth16::NUM_FE_PROOF;
use axiom_eth::utils::encode_addr_to_field;
use ethers::utils::keccak256;
use serde::Deserialize;
use std::{fmt::Debug, vec};

use axiom_circuit::{
    input::flatten::InputFlatten,
    subquery::groth16::{parse_groth16_input, Groth16Input},
};
use axiom_sdk::{halo2_base::utils::biguint_to_fe, Fr};

use ethers::{abi::Address, types::U256};
use num_bigint::BigUint;
use serde::Serialize;
use serde_json::json;
use std::str::FromStr;

use crate::constants::*;

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct ClaimNative {
    pub receiver: Address,
    pub nullifier_hash: String,
    pub proof: Vec<String>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct VkNative {
    vk_alpha_1: [String; 3],
    vk_beta_2: [[String; 2]; 3],
    vk_gamma_2: [[String; 2]; 3],
    vk_delta_2: [[String; 2]; 3],
    IC: [[String; 3]; 5],
}

// https://optimistic.etherscan.io/tx/0x857068d4fbc4434b11e49bcbeb3663ba2b3b89770a5d20203bf206ff0645f104
// https://optimistic.etherscan.io/tx/0xe5ae2511577a857b34efa8a1795f47b875d2885b1b8855775c4d409ae52a9a2b
#[derive(Debug, Deserialize, Serialize)]
pub struct WorldcoinNativeInput {
    pub vk: VkNative,
    pub root: String,
    pub grant_id: String,
    pub num_proofs: usize,
    pub max_proofs: usize,
    pub claims: Vec<ClaimNative>,
}

impl From<WorldcoinNativeInput> for WorldcoinInput<Fr> {
    fn from(input: WorldcoinNativeInput) -> Self {
        let WorldcoinNativeInput {
            vk,
            root,
            grant_id,
            num_proofs,
            max_proofs,
            claims,
        } = input;
        let vk_str = serde_json::to_string(&vk).unwrap();

        WorldcoinInput::new(vk_str, root, grant_id, num_proofs, max_proofs, claims)
    }
}

pub fn get_pf_string(proof: &[String]) -> String {
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

pub fn get_pub_string(
    root: &str,
    external_nullifier_hash: &str,
    nullfiier_hash: &str,
    signal: &Address,
) -> String {
    let signal_hash = get_signal_hash(signal).to_string();
    json!([root, nullfiier_hash, signal_hash, external_nullifier_hash]).to_string()
}

fn get_signal_hash(signal: &Address) -> U256 {
    // solidity:  uint256(keccak256(abi.encodePacked(signal))) >> 8
    // NOTE: ethers Address is case in-sensitive and the checksummed address string
    // will be parsed into lowercase. So the signal_hash is always from lowercase
    // address, make sure the proof public input is also from lowercased address
    let keccak_hash = keccak256(signal.as_bytes());
    U256::from_big_endian(&keccak_hash) >> 8
}

#[derive(Clone, Debug, Default)]
pub struct WorldcoinGroth16Input<T: Copy> {
    pub vkey_bytes: Vec<T>,
    pub proof_bytes: Vec<T>,
    pub public_inputs: Vec<T>,
}

#[derive(Clone, Debug, Default)]
pub struct WorldcoinInput<T: Copy> {
    pub root: T,
    pub grant_id: T,
    pub num_proofs: T,
    pub receivers: Vec<T>,
    pub groth16_inputs: Vec<WorldcoinGroth16Input<T>>,
    pub max_proofs: usize,
}

impl WorldcoinInput<Fr> {
    pub fn new(
        vk_str: String,
        root: String,
        grant_id: String,
        num_proofs: usize,
        max_proofs: usize,
        claims: Vec<ClaimNative>,
    ) -> Self {
        assert!(max_proofs.is_power_of_two());
        assert!(claims.len() == num_proofs);
        assert!(num_proofs > 0);
        assert!(num_proofs <= max_proofs);

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

        let mut groth16_inputs = Vec::new();

        // Currently vk parsing is coupled with pf and pub, we should refactor
        // to have a separate function for parsing vk
        for _i in 0..max_proofs {
            let groth16_input: Groth16Input<Fr> = parse_groth16_input(
                vk_str.clone(),
                pf_strings[_i].clone(),
                pub_strings[_i].clone(),
                MAX_GROTH16_PI,
            );

            groth16_inputs.push(WorldcoinGroth16Input {
                vkey_bytes: groth16_input.vkey_bytes,
                proof_bytes: groth16_input.proof_bytes,
                public_inputs: groth16_input.public_inputs,
            });

            let receiver_fe = encode_addr_to_field(&receivers_native[_i]);
            receivers.push(receiver_fe);
        }

        let root_fe = biguint_to_fe(&BigUint::from_str(root.as_str()).unwrap());

        let grant_id_fe = biguint_to_fe(&BigUint::from_str(grant_id.as_str()).unwrap());

        Self {
            root: root_fe,
            grant_id: grant_id_fe,
            receivers,
            num_proofs: Fr::from(num_proofs as u64),
            max_proofs,
            groth16_inputs,
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct WorldcoinInputCoreParams {
    pub max_proofs: usize,
}

impl Default for WorldcoinInputCoreParams {
    fn default() -> Self {
        Self { max_proofs: 16 }
    }
}

impl<T: Copy> InputFlatten<T> for WorldcoinInput<T> {
    type Params = WorldcoinInputCoreParams;
    const NUM_FE: usize = 0;

    fn flatten_vec(&self) -> Vec<T> {
        let mut flattened_vec = Vec::new();
        flattened_vec.push(self.root);
        flattened_vec.push(self.grant_id);
        flattened_vec.push(self.num_proofs);
        flattened_vec.append(&mut self.receivers.clone());

        for groth16_input in &self.groth16_inputs {
            flattened_vec.append(&mut groth16_input.vkey_bytes.clone());
            flattened_vec.append(&mut groth16_input.proof_bytes.clone());
            flattened_vec.append(&mut groth16_input.public_inputs.clone());
        }

        flattened_vec
    }

    fn unflatten_with_params(vec: Vec<T>, params: Self::Params) -> anyhow::Result<Self> {
        let mut index = 0;
        let root = vec[index];
        let grant_id = vec[index + 1];
        let num_proofs = vec[index + 2];
        index += 3;

        let max_proofs = params.max_proofs;

        let receivers = vec[index..index + max_proofs].to_vec();
        index += max_proofs;

        let mut groth16_inputs = Vec::with_capacity(max_proofs);
        for _ in 0..max_proofs {
            let worldcoin_groth_16_input = WorldcoinGroth16Input {
                vkey_bytes: vec[index..index + NUM_FE_VKEY].to_vec(),
                proof_bytes: vec[index + NUM_FE_VKEY..index + NUM_FE_VKEY + NUM_FE_PROOF].to_vec(),
                public_inputs: vec[index + NUM_FE_VKEY + NUM_FE_PROOF
                    ..index + NUM_FE_VKEY + NUM_FE_PROOF + MAX_GROTH16_PI]
                    .to_vec(),
            };

            groth16_inputs.push(worldcoin_groth_16_input);

            index += NUM_FE_GROTH16_INPUT;
        }

        Ok(WorldcoinInput {
            root,
            grant_id,
            receivers,
            num_proofs,
            max_proofs,
            groth16_inputs,
        })
    }

    fn unflatten(_vec: Vec<T>) -> anyhow::Result<Self> {
        unimplemented!()
    }
}
