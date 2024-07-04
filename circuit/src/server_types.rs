use crate::types::ClaimNative;
use axiom_circuit::types::AxiomV2CircuitOutput;
use ethers::types::H256;
use serde::{Deserialize, Serialize};

pub const CHAIN_ID: u64 = 11155111;

pub const V1_CALLBACK_TARGET: &str = "0x27ff9334e2b75b838baeb78618d12ced843c075d";
pub const V2_CALLBACK_TARGET: &str = "0x3f88b9dc416ceadc36092673097ba456ba878cfb";
pub const CALLBACK_EXTRA_DATA: &str = "0x";

#[derive(Debug, Deserialize, Serialize)]
pub struct WorldcoinRequest {
    pub root: String,
    pub grant_id: String,
    pub num_proofs: usize,
    pub max_proofs: usize,
    pub claims: Vec<ClaimNative>,
}

#[derive(Default, Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FeeData {
    pub max_fee_per_gas: String,
    pub callback_gas_limit: Option<u64>,
    pub override_axiom_query_fee: Option<String>,
}

#[derive(Default, Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Callback {
    pub target: String,
    pub extra_data: String,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct V2QueryRequestInner {
    pub source: String,
    pub source_chain_id: u64,
    pub target_chain_id: u64,
    pub user_salt: H256,
    pub callback: Callback,
    pub fee_data: FeeData,
    #[serde(flatten)]
    pub compute_query: AxiomV2CircuitOutput,
}

#[derive(Debug, Clone, Serialize)]
pub struct V2QueryRequest {
    pub params: V2QueryRequestInner,
}

impl From<V2QueryRequestInner> for V2QueryRequest {
    fn from(params: V2QueryRequestInner) -> Self {
        V2QueryRequest { params }
    }
}

pub fn create_v2_query_request(
    chain_id: u64,
    callback: Callback,
    mut fee_data: FeeData,
    compute_query: AxiomV2CircuitOutput,
) -> V2QueryRequest {
    fee_data.callback_gas_limit.get_or_insert(100_000);
    fee_data
        .override_axiom_query_fee
        .get_or_insert("0x0".to_string());
    V2QueryRequestInner {
        source: "Api".to_string(),
        source_chain_id: chain_id,
        target_chain_id: chain_id,
        user_salt: H256::random(),
        callback,
        fee_data,
        compute_query,
    }
    .into()
}

pub enum Version {
    V1,
    V2,
}

impl Version {
    pub fn to_string(&self) -> String {
        match self {
            Version::V1 => "v1".to_owned(),
            Version::V2 => "v2".to_owned(),
        }
    }
}
