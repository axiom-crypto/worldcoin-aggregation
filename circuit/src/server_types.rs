use crate::types::ClaimNative;
use axiom_circuit::types::AxiomV2CircuitOutput;
use ethers::types::H256;
use serde::{Deserialize, Serialize};
use phf::{phf_map, Map};

pub const CHAIN_ID: u64 = 11155111;


pub static V1_MAP: Map<u32, &'static str> = phf_map! {
    8u32 => "0x0Af226d96d3f149875bec102D71779BcF58e2800",
    16u32 => "0x27ff9334e2b75b838baeb78618d12ced843c075d",
    32u32 => "0xE3C5d7441890048C472c52167453f349b1216b87",
    64u32 => "0xF81a28F081d7Cd5Ba695E43D4c8aB0A991f17982",
    128u32=> "0x5F9c52B43Fc8E2080463e6246318203596FCB887",
};

pub static V2_MAP: Map<u32, &'static str> = phf_map! {
    8u32 => "0x051e0aB85c4Dfb90270FD45c93628c7F0b7551e7",
    16u32 => "0x3f88b9dc416ceadc36092673097ba456ba878cfb",
    32u32 => "0x95c07C58d95dEab6ff7bA273b2B582394539289E",
    64u32 => "0x7400fA7E1da16D995EC5F8F717a61D974C02BfAc",
    128u32=> "0x0CBb51Fd7fbfc36A342C3D35316B814C825EA552",
};

pub static CALLBACK_TARGETS: Map<&'static str, &Map<u32, &'static str>> = phf_map! {
    "v1" => &V1_MAP,
    "v2" => &V2_MAP,
};

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
    fee_data.callback_gas_limit.get_or_insert(1_000_000);
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
