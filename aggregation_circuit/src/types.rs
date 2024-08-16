use std::{fmt::Display, io::Cursor};

use rocket::{
    response::{self, Responder},
    Request,
};

use axiom_components::{
    groth16::types::{
        Groth16VerifierComponentProof, Groth16VerifierComponentVerificationKey,
        Groth16VerifierInput,
    },
    utils::flatten::InputFlatten,
};
use axiom_eth::{
    halo2_base::{AssignedValue, Context},
    utils::encode_addr_to_field,
    zkevm_hashes::util::eth_types::Field,
};
use ethers::utils::keccak256;
use serde::Deserialize;
use std::fmt::Debug;

use axiom_components::groth16::{get_groth16_consts_from_max_pi, test::parse_input};

use axiom_eth::{halo2_base::utils::biguint_to_fe, halo2curves::bn256::Fr};

use crate::constants::*;
use ethers::{abi::Address, types::U256};
use num_bigint::BigUint;
use serde::Serialize;
use serde_json::json;
use std::str::FromStr;

pub type Result<T> = std::result::Result<T, Error>;

/// Wrapper around [`anyhow::Error`]
/// with Rocket's [Responder] implemented
///
/// This is taken from https://docs.rs/rocket_anyhow/latest/rocket_anyhow/ but
/// updated for Rocket v0.5
#[derive(Debug)]
pub struct Error(pub anyhow::Error);

#[derive(Clone, Copy, Debug)]
pub struct InvalidInputContext;

impl<E> From<E> for Error
where
    E: Into<anyhow::Error>,
{
    fn from(error: E) -> Self {
        Error(error.into())
    }
}

impl<'r, 'o: 'r> Responder<'r, 'o> for Error {
    fn respond_to(self, _: &'r Request<'_>) -> response::Result<'o> {
        // For the sake of this example, let's just return a 500 error with the error's message.
        // In a real-world application, you might want to handle different error cases more specifically.
        let mut response = rocket::Response::build();
        if self.0.downcast_ref::<InvalidInputContext>().is_some() {
            response.status(rocket::http::Status::BadRequest);
        } else {
            response.status(rocket::http::Status::InternalServerError);
        }
        let msg = self.0.to_string();
        response
            .header(rocket::http::ContentType::Plain)
            .sized_body(msg.len(), Cursor::new(msg))
            .ok()
    }
}

impl Display for InvalidInputContext {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "InvalidInput")
    }
}

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
#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct WorldcoinNativeInput {
    pub vk: VkNative,
    pub root: String,
    pub grant_id: String,
    pub num_proofs: usize,
    pub max_proofs: usize,
    pub claims: Vec<ClaimNative>,
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

#[derive(Clone, Debug, Serialize)]
pub struct Groth16Input<T: Copy> {
    pub vkey_bytes: Vec<T>,
    pub proof_bytes: Vec<T>,
    pub public_inputs: Vec<T>,
}

impl<F: Field> From<Groth16Input<F>> for Groth16VerifierInput<F> {
    fn from(input: Groth16Input<F>) -> Self {
        let constants = get_groth16_consts_from_max_pi(MAX_GROTH16_PI);

        let vk = Groth16VerifierComponentVerificationKey::unflatten(
            input.vkey_bytes,
            constants.gamma_abc_g1_len,
        );
        let proof = Groth16VerifierComponentProof::unflatten(input.proof_bytes).unwrap();
        let num_public_inputs = F::from((MAX_GROTH16_PI + 1) as u64);

        Groth16VerifierInput {
            vk,
            proof,
            num_public_inputs,
            public_inputs: input.public_inputs,
        }
    }
}

pub struct WorldcoinAssignedInput<F: Field> {
    pub start: AssignedValue<F>,
    pub end: AssignedValue<F>,
    pub root: AssignedValue<F>,
    pub grant_id: AssignedValue<F>,
    pub receivers: Vec<AssignedValue<F>>,
    pub groth16_verifier_inputs: Vec<Groth16VerifierInput<AssignedValue<F>>>,
}

impl<T: Copy> From<Groth16VerifierInput<T>> for Groth16Input<T> {
    fn from(input: Groth16VerifierInput<T>) -> Self {
        let flattened_vkey = input.vk.flatten();
        let flattened_proof = input.proof.flatten_vec();
        Groth16Input {
            vkey_bytes: flattened_vkey,
            proof_bytes: flattened_proof,
            public_inputs: input.public_inputs,
        }
    }
}

#[derive(Debug, Deserialize, Serialize)]
pub struct WorldcoinRequest {
    pub root: String,
    pub grant_id: String,
    pub num_proofs: usize,
    pub max_proofs: usize,
    pub claims: Vec<ClaimNative>,
}
