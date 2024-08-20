use std::{fmt::Display, io::Cursor};

use rocket::{
    response::{self, Responder},
    Request,
};

use axiom_components::{
    groth16::{
        types::{Groth16VerifierComponentProof, Groth16VerifierComponentVerificationKey},
        utils::{vec_to_hilo_pair, vec_to_hilo_point, HiLoPair, HiLoPoint},
    },
    utils::flatten::InputFlatten,
};
use axiom_eth::{
    halo2_base::AssignedValue, utils::hilo::HiLo, zkevm_hashes::util::eth_types::Field,
};
use serde::Deserialize;
use std::fmt::Debug;

use axiom_components::groth16::get_groth16_consts_from_max_pi;

use axiom_eth::halo2curves::bn256::Fr;

use ethers::abi::Address;
use itertools::Itertools;
use serde::Serialize;
use serde_json::json;

macro_rules! deserialize_key {
    ($json: expr, $val: expr) => {
        serde_json::from_value($json[$val].clone()).unwrap()
    };
}

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

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ClaimInput<T: Copy> {
    pub receiver: T,
    pub nullifier_hash: T,
    pub proof_bytes: Vec<T>,
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
// NOTE: ethers Address is case in-sensitive and the checksummed address string
// will be parsed into lowercase. So the signal_hash is always from lowercase
// address, make sure the proof public input is also from lowercased address
#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct WorldcoinNativeInput {
    pub vk: VkNative,
    pub root: String,
    pub grant_id: String,
    pub num_proofs: usize,
    pub max_proofs: usize,
    pub claims: Vec<ClaimNative>,
}

pub fn parse_vk(vk_string: String, max_pi: usize) -> Vec<Fr> {
    let input_constants = get_groth16_consts_from_max_pi(max_pi);
    let verification_key_file: serde_json::Value =
        serde_json::from_str(vk_string.as_str()).unwrap();

    let vk_alpha_1: [String; 3] = deserialize_key!(verification_key_file, "vk_alpha_1");
    let vk_beta_2: [[String; 2]; 3] = deserialize_key!(verification_key_file, "vk_beta_2");
    let vk_gamma_2: [[String; 2]; 3] = deserialize_key!(verification_key_file, "vk_gamma_2");
    let vk_delta_2: [[String; 2]; 3] = deserialize_key!(verification_key_file, "vk_delta_2");

    let alpha_g1: HiLoPoint<Fr> = vec_to_hilo_point(&vk_alpha_1);
    let beta_g2: HiLoPair<Fr> = vec_to_hilo_pair(&vk_beta_2);
    let gamma_g2: HiLoPair<Fr> = vec_to_hilo_pair(&vk_gamma_2);
    let delta_g2: HiLoPair<Fr> = vec_to_hilo_pair(&vk_delta_2);

    let ic: Vec<[String; 3]> = deserialize_key!(verification_key_file, "IC");
    let mut ic_vec: Vec<HiLoPoint<Fr>> =
        ic.into_iter().map(|s| vec_to_hilo_point(&s)).collect_vec();
    ic_vec.resize(
        input_constants.gamma_abc_g1_len,
        (HiLo::default(), HiLo::default()),
    );

    let vk = Groth16VerifierComponentVerificationKey {
        alpha_g1,
        beta_g2,
        gamma_g2,
        delta_g2,
        gamma_abc_g1: ic_vec,
    };
    vk.flatten()
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

pub fn parse_proof(pf_string: String) -> Vec<Fr> {
    let proof_file: serde_json::Value = serde_json::from_str(pf_string.as_str()).unwrap();

    // get proof
    let a: [String; 3] = deserialize_key!(proof_file, "pi_a");
    let b: [[String; 2]; 3] = deserialize_key!(proof_file, "pi_b");
    let c: [String; 3] = deserialize_key!(proof_file, "pi_c");

    let a: HiLoPoint<Fr> = vec_to_hilo_point(&a);
    let b: HiLoPair<Fr> = vec_to_hilo_pair(&b);
    let c: HiLoPoint<Fr> = vec_to_hilo_point(&c);

    let pf = Groth16VerifierComponentProof { a, b, c };

    pf.flatten_vec()
}

pub struct WorldcoinAssignedInput<F: Field> {
    pub start: AssignedValue<F>,
    pub end: AssignedValue<F>,
    pub root: AssignedValue<F>,
    pub grant_id: AssignedValue<F>,
    pub vk_bytes: Vec<AssignedValue<F>>,
    pub claims: Vec<ClaimInput<AssignedValue<F>>>,
    pub num_public_inputs: AssignedValue<F>,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct WorldcoinRequest {
    pub root: String,
    pub grant_id: String,
    pub num_proofs: usize,
    pub max_proofs: usize,
    pub claims: Vec<ClaimNative>,
}
