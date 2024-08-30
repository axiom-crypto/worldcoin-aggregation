use abi::Abi;
use ethers::prelude::*;
use std::str::FromStr;
use std::sync::Arc;

use crate::types::ClaimNative;
use ethers::types::Bytes;
use hex::FromHex;

#[derive(Debug, Clone)]
pub struct V1ClaimParams {
    vkey_hash: H256,
    num_claims: U256,
    root: U256,
    grant_ids: Vec<U256>,
    receivers: Vec<Address>,
    nullifier_hashes: Vec<U256>,
    proof: Bytes,
}

impl V1ClaimParams {
    pub fn new(vkey_hash: &str, root: &str, claims: &Vec<ClaimNative>, proof: String) -> Self {
        let vkey_hash = H256::from_str(vkey_hash).expect("Invalid H256 string");

        let root = U256::from_str_radix(root, 10).expect("Invalid root string");
        let num_claims = U256::from(claims.len() as u64); // Example conversion for num_claims

        let nullifier_hashes = claims
            .iter()
            .map(|claim| {
                U256::from_str_radix(&claim.nullifier_hash, 10).expect("Invalid nullifier_hash")
            })
            .collect();

        let receivers: Vec<Address> = claims.iter().map(|claim| claim.receiver).collect();

        let grant_ids: Vec<U256> = claims
            .iter()
            .map(|claim| U256::from_str_radix(&claim.grant_id, 10).expect("Invalid grant_id"))
            .collect();

        let proof = Vec::from_hex(proof).expect("Invalid hex string");
        let proof = Bytes::from(proof);

        Self {
            vkey_hash,
            num_claims,
            root,
            grant_ids,
            receivers,
            nullifier_hashes,
            proof,
        }
    }
}

pub struct ContractClient {
    contract_client: Contract<SignerMiddleware<Provider<Http>, Wallet<k256::ecdsa::SigningKey>>>,
}

impl ContractClient {
    pub fn new(
        keystore_path: &str,
        password: &str,
        provider_uri: &str,
        contract_address: &str,
        chain_id: u64,
    ) -> Result<Self, Box<dyn std::error::Error>> {
        let provider: Provider<Http> = Provider::<Http>::try_from(provider_uri)?;

        // ethers-rs wallet initialization needs to use the correct chain_id, otherwise error occurs in broadcasting tx
        let wallet = Wallet::decrypt_keystore(keystore_path, password)
            .unwrap()
            .with_chain_id(chain_id);

        let contract_address: Address = contract_address.parse()?;
        #[cfg(feature = "v1")]
        let abi = include_str!("../../abi/WorldcoinAggregationV1Abi.json");
        #[cfg(feature = "v2")]
        let abi = include_str!("../../abi/WorldcoinAggregationV2Abi.json");

        let abi: Abi = serde_json::from_str(&abi)?;
        let client = SignerMiddleware::new(provider.clone(), wallet.clone());

        let contract_client = Contract::new(contract_address, abi, Arc::new(client));

        Ok(Self { contract_client })
    }

    // example tx: https://sepolia.etherscan.io/tx/0x3d7488e27ba42f02bc15a2228364fa202b50d94e9fdeffbfcd9fb0b0b950b3c1
    #[cfg(feature = "v1")]
    pub async fn fulfill(&self, params: V1ClaimParams) -> anyhow::Result<H256> {
        let receipt = self
            .contract_client
            .method::<_, ()>(
                "distributeGrants",
                (
                    params.vkey_hash,
                    params.num_claims,
                    params.root,
                    params.grant_ids,
                    params.receivers,
                    params.nullifier_hashes,
                    params.proof,
                ),
            )?
            .send()
            .await?
            .await?
            .unwrap();

        Ok(receipt.transaction_hash)
    }

    #[cfg(feature = "v2")]
    pub async fn fulfill(&self, proof: String) -> anyhow::Result<H256> {
        let proof = Vec::from_hex(proof).expect("Invalid hex string");
        let proof = Bytes::from(proof);
        let receipt = self
            .contract_client
            .method::<_, ()>("validateClaimsRoot", proof)?
            .send()
            .await?
            .await?
            .unwrap();

        Ok(receipt.transaction_hash)
    }
}
