use axiom_components::groth16::NUM_FE_PROOF;
use axiom_eth::utils::encode_addr_to_field;
use serde::Deserialize;
use std::fmt::Debug;

use axiom_circuit::{
    input::flatten::InputFlatten,
    subquery::groth16::{parse_groth16_input, Groth16Input},
};
use axiom_sdk::{halo2_base::utils::biguint_to_fe, Fr};

use ethers::{abi::Address, types::H256};
use num_bigint::BigUint;
use serde::Serialize;
use std::str::FromStr;

use crate::constants::*;
use crate::types::{
    get_pf_string, get_pub_string, VkNative, WorldcoinGroth16Input, WorldcoinInputCoreParams,
};

use axiom_eth::halo2curves::{
    ff::{Field as RawField, PrimeField},
    secp256k1::{Fp, Fq, Secp256k1Affine},
};

use axiom_eth::utils::encode_h256_to_hilo;
use axiom_sdk::HiLo;

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct WorldIdBalanceRecordNative {
    pub address: Address,
    pub nullifier_hash: String,
    pub proof: Vec<String>,
    pub signature: String,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct WorldIdBalanceNativeInput {
    pub vk: VkNative,
    pub root: String,
    pub external_nullifier_hash: String,
    pub num_proofs: usize,
    pub max_proofs: usize,
    pub records: Vec<WorldIdBalanceRecordNative>,
    pub block_number: u64,
    pub message_hash: H256,
}

#[derive(Clone, Debug)]
pub struct Signature<T: Copy> {
    pub r: HiLo<T>,
    pub s: HiLo<T>,
}

#[derive(Clone, Debug, Default)]
pub struct WorldIdBalanceInput<T: Copy> {
    pub root: T,
    pub external_nullifier_hash: T,
    pub num_proofs: T,
    pub addresses: Vec<T>,
    pub message_hash: HiLo<T>,
    pub block_number: T,
    pub groth16_inputs: Vec<WorldcoinGroth16Input<T>>,
    pub signatures: Vec<Signature<T>>,
    pub max_proofs: usize,
    pub pubkeys: Vec<(HiLo<T>, HiLo<T>)>,
}

impl From<WorldIdBalanceNativeInput> for WorldIdBalanceInput<Fr> {
    fn from(input: WorldIdBalanceNativeInput) -> Self {
        let WorldIdBalanceNativeInput {
            vk,
            root,
            external_nullifier_hash,
            num_proofs,
            max_proofs,
            records,
            block_number,
            message_hash,
        } = input;
        let vk_str = serde_json::to_string(&vk).unwrap();

        WorldIdBalanceInput::new(
            vk_str,
            root,
            external_nullifier_hash,
            num_proofs,
            max_proofs,
            records,
            block_number,
            message_hash,
        )
    }
}

impl WorldIdBalanceInput<Fr> {
    pub fn new(
        vk_str: String,
        root: String,
        external_nullifier_hash: String,
        num_proofs: usize,
        max_proofs: usize,
        records: Vec<WorldIdBalanceRecordNative>,
        block_number: u64,
        message_hash: H256,
    ) -> Self {
        assert!(max_proofs.is_power_of_two());
        assert!(records.len() == num_proofs);
        assert!(num_proofs > 0);
        assert!(num_proofs <= max_proofs);

        let mut pf_strings: Vec<String> = Vec::new();
        let mut pub_strings: Vec<String> = Vec::new();
        let mut addresses: Vec<Fr> = Vec::new();
        let mut addresses_native: Vec<Address> = Vec::new();
        //let mut signatures: Vec<Signature<Fr>> = Vec::new();
        let mut signatures_native: Vec<String> = Vec::new();

        for _i in 0..num_proofs {
            let pf_string = get_pf_string(&records[_i].proof);
            let pub_string = get_pub_string(
                &root,
                &external_nullifier_hash,
                &records[_i].nullifier_hash,
                &records[_i].address,
            );
            pf_strings.push(pf_string);
            pub_strings.push(pub_string);
            addresses_native.push(records[_i].address);
            signatures_native.push(records[_i].signature.clone());
        }

        pf_strings.resize(max_proofs, pf_strings[0].clone());
        pub_strings.resize(max_proofs, pub_strings[0].clone());
        addresses_native.resize(max_proofs, addresses_native[0].clone());
        signatures_native.resize(max_proofs, signatures_native[0].clone());

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

            let receiver_fe = encode_addr_to_field(&addresses_native[_i]);
            addresses.push(receiver_fe);
        }

        let signatures: Vec<Vec<u8>> = signatures_native
            .into_iter()
            .map(|s| {
                assert_eq!(s.len(), 132);

                hex::decode(&s[2..]).unwrap()
            })
            .collect();

        let pubkeys = signatures
            .iter()
            .map(|s| {
                let pubkey = get_pubkey(&message_hash.as_bytes().to_vec(), s);

                let x_hilo = {
                    let mut bytes = pubkey.x.to_repr().to_vec();
                    bytes.reverse();
                    let base = Fr::from(256);
                    let mut x_lo = Fr::from(0);
                    let mut x_hi = x_lo;
                    for i in 16..32 {
                        x_lo *= base;
                        x_lo += Fr::from(bytes[i] as u64);
                    }
                    for i in 0..16 {
                        x_hi *= base;
                        x_hi += Fr::from(bytes[i] as u64);
                    }
                    HiLo::from_hi_lo([x_hi, x_lo])
                };
                let y_hilo = {
                    let mut bytes = pubkey.y.to_repr().to_vec();
                    bytes.reverse();
                    let base = Fr::from(256);
                    let mut y_lo = Fr::from(0);
                    let mut y_hi = y_lo;
                    for i in 16..32 {
                        y_lo *= base;
                        y_lo += Fr::from(bytes[i] as u64);
                    }
                    for i in 0..16 {
                        y_hi *= base;
                        y_hi += Fr::from(bytes[i] as u64);
                    }
                    HiLo::from_hi_lo([y_hi, y_lo])
                };

                (x_hilo, y_hilo)
            })
            .collect();

        let signatures: Vec<Signature<Fr>> = signatures
            .into_iter()
            .map(|sig| {
                let r = H256(sig[0..32].to_vec().try_into().unwrap());
                let s = H256(sig[32..64].to_vec().try_into().unwrap());
                let sig = Signature {
                    r: encode_h256_to_hilo(&r),
                    s: encode_h256_to_hilo(&s),
                };
                // println!("{:02x?}", sig);
                sig
            })
            .collect();

        let root = biguint_to_fe(&BigUint::from_str(root.as_str()).unwrap());

        let external_nullifier_hash =
            biguint_to_fe(&BigUint::from_str(external_nullifier_hash.as_str()).unwrap());

        let message_hash = encode_h256_to_hilo(&message_hash);

        Self {
            root,
            external_nullifier_hash,
            addresses,
            num_proofs: Fr::from(num_proofs as u64),
            max_proofs,
            block_number: Fr::from(block_number),
            groth16_inputs,
            message_hash,
            signatures,
            pubkeys,
        }
    }
}

impl<T: Copy> InputFlatten<T> for WorldIdBalanceInput<T> {
    type Params = WorldcoinInputCoreParams;
    const NUM_FE: usize = 0;

    fn flatten_vec(&self) -> Vec<T> {
        let mut flattened_vec = Vec::new();
        flattened_vec.push(self.root);
        flattened_vec.push(self.external_nullifier_hash);
        flattened_vec.push(self.num_proofs);
        flattened_vec.push(self.block_number);
        let mut message_hash_vec = self.message_hash.flatten_vec();
        flattened_vec.append(&mut message_hash_vec);
        flattened_vec.append(&mut self.addresses.clone());

        for groth16_input in &self.groth16_inputs {
            flattened_vec.append(&mut groth16_input.vkey_bytes.clone());
            flattened_vec.append(&mut groth16_input.proof_bytes.clone());
            flattened_vec.append(&mut groth16_input.public_inputs.clone());
        }

        for sig in &self.signatures {
            flattened_vec.append(&mut sig.r.flatten_vec());
            flattened_vec.append(&mut sig.s.flatten_vec());
        }

        for pubkey in &self.pubkeys {
            flattened_vec.append(&mut pubkey.0.flatten_vec());
            flattened_vec.append(&mut pubkey.1.flatten_vec());
        }

        flattened_vec
    }

    fn unflatten_with_params(vec: Vec<T>, params: Self::Params) -> anyhow::Result<Self> {
        let mut index = 0;
        let root = vec[index];
        let external_nullifier_hash = vec[index + 1];
        let num_proofs = vec[index + 2];
        let block_number = vec[index + 3];
        let message_hash = HiLo::from_hi_lo([vec[index + 4], vec[index + 5]]);
        index += 6;

        let max_proofs = params.max_proofs;

        let addresses = vec[index..index + max_proofs].to_vec();
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
        let mut signatures = Vec::with_capacity(max_proofs);
        for _ in 0..max_proofs {
            let r = HiLo::from_hi_lo([vec[index], vec[index + 1]]);
            let s = HiLo::from_hi_lo([vec[index + 2], vec[index + 3]]);
            signatures.push(Signature { r, s });
            index += 4;
        }

        let mut pubkeys = Vec::with_capacity(max_proofs);
        for _ in 0..max_proofs {
            let pubkey = (
                HiLo::from_hi_lo([vec[index], vec[index + 1]]),
                HiLo::from_hi_lo([vec[index + 2], vec[index + 3]]),
            );
            pubkeys.push(pubkey);
            index += 4;
        }

        Ok(WorldIdBalanceInput {
            root,
            external_nullifier_hash,
            addresses,
            block_number,
            message_hash,
            num_proofs,
            max_proofs,
            groth16_inputs,
            signatures,
            pubkeys,
        })
    }

    fn unflatten(_vec: Vec<T>) -> anyhow::Result<Self> {
        unimplemented!()
    }
}

/// given message and signature, recovers the pubkey
// steps:
// compute (r,s,v) = signature (32,32,1) bytes, respectively
// v = 27: take x1 = r, else v = 28: take x1 = r + n on the base field
// compute R(x1, y1) a point on the elliptic curve
// y1 = sqrt(x1^3 + 7) on the base field
//u1 = -zr^-1 mod n, u2 = sr^-1 mod n
// Q = u1*G + u2 *R is the point of pubkey, returned as a curve element of Secp256k1Affine
#[allow(non_snake_case)]
pub fn get_pubkey(msghash: &Vec<u8>, sig: &Vec<u8>) -> Secp256k1Affine {
    // get modulus, turn string into bytes
    let n = Fq::MODULUS;
    let n = n.trim_start_matches("0x"); // Remove the 0x prefix
    let mut n = hex::decode(n).unwrap();
    n.reverse();
    let n_bytes = n.try_into().unwrap();

    let n_field_base = Fp::from_bytes(&n_bytes).unwrap();
    // println!("{:?}", n_field_base);
    let mut z = msghash[0..32].to_vec();
    let mut r = sig[..32].to_vec();
    let mut s = sig[32..64].to_vec();
    let v = sig[64];

    z.reverse();
    r.reverse();
    s.reverse();

    let r_bytes = r.try_into().unwrap();
    let s_bytes = s.try_into().unwrap();
    let z_bytes = z.try_into().unwrap();

    let r_field_scalar = Fq::from_bytes(&r_bytes).unwrap();
    let r_field_base = Fp::from_bytes(&r_bytes).unwrap();
    let s_field_scalar = Fq::from_bytes(&s_bytes).unwrap();
    let z_field_scalar = Fq::from_bytes(&z_bytes).unwrap();

    let mut x1 = r_field_base;

    // 27 = lower X even Y. 28 = lower X odd Y. 29 = higher X even Y. 30 = higher X odd Y
    // above is the v term in recovery

    if v == 29 || v == 30 {
        x1 = r_field_base + n_field_base;
    }

    let y1_squared = x1 * x1 * x1 + Fp::from(7);
    let mut y1 = y1_squared.sqrt().unwrap();

    if v == 27 || v == 29 {
        if y1.is_odd().unwrap_u8() == 1 {
            y1 = -y1;
        }
    } else if (v == 28 || v == 30) && y1.is_even().unwrap_u8() == 1 {
        y1 = -y1;
    }
    let u1 = -z_field_scalar * r_field_scalar.invert().unwrap();
    let u2 = s_field_scalar * r_field_scalar.invert().unwrap();
    let R = Secp256k1Affine { x: x1, y: y1 };
    let Q1 = Secp256k1Affine::from(Secp256k1Affine::generator() * u1);
    let Q2 = Secp256k1Affine::from(R * u2);
    let Q = Q1 + Q2;
    Q.into()
}
