#[macro_use]
extern crate rocket;

use axiom_circuit::scaffold::AxiomCircuitScaffold;
use axiom_sdk::Fr;
use client_circuit::circuit_v1::WorldcoinV1Circuit;
use client_circuit::circuit_v2::WorldcoinV2Circuit;

use client_circuit::types::{VkNative, WorldcoinInputCoreParams, WorldcoinNativeInput};

use ethers::providers::Middleware;
use rocket::serde::json::Json;
use std::fs::File;

use ethers::prelude::Http;
use ethers::prelude::Provider;

use axiom_circuit::{
    run::{aggregation::agg_circuit_run, inner::run},
    scaffold::AxiomCircuit,
    types::AxiomCircuitParams,
};

use axiom_codec::constants::{USER_MAX_OUTPUTS, USER_MAX_SUBQUERIES};
use axiom_eth::halo2_base::gates::circuit::BaseCircuitParams;
use axiom_eth::rlc::circuit::RlcCircuitParams;
use axiom_eth::utils::keccak::decorator::RlcKeccakCircuitParams;
use axiom_sdk::cli::types::RawCircuitParams;
use axiom_sdk::utils::{
    io::{read_agg_pk_and_pinning, read_metadata, read_pk_and_pinning},
    read_srs_from_dir_or_install,
};

use reqwest::Client;
use rocket::State;
use std::env;
use std::path::PathBuf;
use tokio::runtime::Runtime;

use ethers::types::U256;

use client_circuit::server_types::*;
use ethers::types::BlockId;

pub struct Context {
    qm_url_v1: String,
    qm_url_v2: String,
    provider_uri: String,
    vk: VkNative,
}

#[get("/")]
fn index() -> &'static str {
    "I'm alive!"
}

fn prove_with_aggregation<A: AxiomCircuitScaffold<Http, Fr>>(
    qm_url: String,
    provider_uri: String,
    max_proofs: usize,
    input: A::InputValue,
    version: Version,
) -> Result<String, String> {
    let provider = Provider::<Http>::try_from(provider_uri).unwrap();
    let data_path = PathBuf::from(format!("./data/{}/{}", version.to_string(), max_proofs));
    let srs_path: PathBuf = dirs::home_dir().unwrap().join(".axiom/srs/challenge_0085");

    let config = if max_proofs > 32 {
        format!("./configs/config_{}_{}.json", max_proofs, version.to_string())
    } else {
        format!("./configs/config_{}.json", max_proofs)
    };
    let raw_params: RawCircuitParams<A::CoreParams> =
        serde_json::from_reader(File::open(config).unwrap()).unwrap();
    let max_user_outputs = raw_params.max_outputs.unwrap_or(USER_MAX_OUTPUTS);
    let max_subqueries = raw_params.max_subqueries.unwrap_or(USER_MAX_SUBQUERIES);
    let max_groth16_pi = raw_params.max_groth16_pi.unwrap_or(4);
    let core_params = raw_params
        .core_params
        .unwrap_or_else(A::CoreParams::default);

    let base_params = BaseCircuitParams {
        k: raw_params.k,
        num_advice_per_phase: raw_params.num_advice_per_phase,
        num_fixed: raw_params.num_fixed,
        num_lookup_advice_per_phase: raw_params.num_lookup_advice_per_phase,
        lookup_bits: raw_params.lookup_bits,
        num_instance_columns: 1,
    };

    let params = AxiomCircuitParams::Keccak(RlcKeccakCircuitParams {
        keccak_rows_per_round: raw_params.keccak_rows_per_round.unwrap(),
        rlc: RlcCircuitParams {
            base: base_params,
            num_rlc_columns: 0,
        },
    });

    let runner: AxiomCircuit<Fr, Http, A> =
        AxiomCircuit::<Fr, Http, A>::new(provider.clone(), params)
            .use_core_params(core_params)
            .use_max_user_outputs(max_user_outputs)
            .use_max_user_subqueries(max_subqueries)
            .use_max_groth16_pi(max_groth16_pi)
            .use_inputs(Some(input.clone()));

    let metadata = read_metadata(data_path.join("circuit.json"));

    let circuit_id = metadata.circuit_id.clone();
    let (pk, pinning) = read_pk_and_pinning(data_path.clone(), circuit_id, &runner);
    let prover = AxiomCircuit::<Fr, Http, A>::prover(provider.clone(), pinning.clone())
        .use_inputs(Some(input));
    let srs = read_srs_from_dir_or_install(&srs_path, prover.k() as u32);
    let inner_output = run(prover, &pk, &srs);

    let agg_circuit_id = metadata.agg_circuit_id.expect("No aggregation circuit ID");
    let (agg_pk, agg_pinning) =
        read_agg_pk_and_pinning::<WorldcoinInputCoreParams>(data_path.clone(), agg_circuit_id);
    let agg_srs = read_srs_from_dir_or_install(&srs_path, agg_pinning.params.degree);
    let output = agg_circuit_run(agg_pinning, inner_output, &agg_pk, &agg_srs);


    let callback = Callback {
        target: CALLBACK_TARGETS[&(version.to_string())][&(max_proofs as u32)].to_string(),
        extra_data: CALLBACK_EXTRA_DATA.to_string(),
    };

    let rt = Runtime::new().unwrap();
    let client = Client::new();

    let max_fee_per_gas = rt.block_on(async {
        let block = provider
            .get_block_with_txs(BlockId::Number(ethers::types::BlockNumber::Latest))
            .await
            .unwrap();

        let max_fee_per_gas = block
            .map(|b| b.base_fee_per_gas.unwrap_or(U256::zero()) * 2)
            .unwrap_or(U256::zero());

        let max_fee_per_gas = max_fee_per_gas + 500_000_000;
        max_fee_per_gas
    });

    let mut callback_gas_limit = 600_000;
    if let Version::V1 = version {
        callback_gas_limit += 55_000 * max_proofs;
    }

    let v2_req = create_v2_query_request(
        CHAIN_ID,
        callback,
        FeeData {
            max_fee_per_gas: max_fee_per_gas.to_string(),
            callback_gas_limit: Some(callback_gas_limit as u64),
            override_axiom_query_fee: None,
        },
        output,
    );

    let body = serde_json::to_string(&v2_req).expect("Unable to convert request to JSON string");

    let res = rt.block_on(async {
        client
            .post(qm_url)
            .header("Content-Type", "application/json")
            .body(body)
            .send()
            .await
    });

    match res {
        Ok(response) => {
            if response.status().is_success() {
                Ok("Query started successfully".to_string())
            } else {
                println!("Failed to start query: {:?}", response.status());
                let text = rt.block_on(async { response.text().await }).unwrap();
                println!("{:?}", text);
                Err("Failed to send request".to_string())
            }
        }
        Err(e) => {
            println!("Failed to send request: {:?}", e);
            Err("Failed to send request".to_string())
        }
    }
}

#[post("/v1", format = "json", data = "<request>")]
async fn batch_verify_v1(
    request: Json<WorldcoinRequest>,
    context: &State<Context>,
) -> Result<String, String> {
    let qm_url: String = context.qm_url_v1.clone();
    let provider_uri: String = context.provider_uri.clone();
    let request = request.into_inner();
    let input = WorldcoinNativeInput {
        vk: context.vk.clone(),
        root: request.root,
        grant_id: request.grant_id,
        num_proofs: request.num_proofs,
        max_proofs: request.max_proofs,
        claims: request.claims,
    };

    let _handler = std::thread::spawn(move || {
        let res = prove_with_aggregation::<WorldcoinV1Circuit>(
            qm_url,
            provider_uri,
            input.max_proofs,
            input.clone().into(),
            Version::V1,
        );
        if let Err(e) = res {
            println!("Request {:?} failed", input);
        }
    });

    Ok("Query started successfully".to_string())
}

#[post("/v2", format = "json", data = "<request>")]
fn batch_verify_v2(
    request: Json<WorldcoinRequest>,
    context: &State<Context>,
) -> Result<String, String> {
    let qm_url: String = context.qm_url_v2.clone();
    let provider_uri: String = context.provider_uri.clone();
    let request = request.into_inner();
    let input = WorldcoinNativeInput {
        vk: context.vk.clone(),
        root: request.root,
        grant_id: request.grant_id,
        num_proofs: request.num_proofs,
        max_proofs: request.max_proofs,
        claims: request.claims,
    };

    let _handler = std::thread::spawn(move || {
        let res = prove_with_aggregation::<WorldcoinV2Circuit>(
            qm_url,
            provider_uri,
            input.max_proofs,
            input.clone().into(),
            Version::V2,
        );

        if let Err(e) = res {
            println!("Request {:?} failed", input);
        }
    });

    Ok("Query started successfully".to_string())
}

#[launch]
fn rocket() -> _ {
    let qm_url_v1 = env::var("QM_URL_V1").unwrap_or_else(|_| panic!("QM_URL_V1 not set"));
    let qm_url_v2 = env::var("QM_URL_V2").unwrap_or_else(|_| panic!("QM_URL_V2 not set"));
    let provider_uri = env::var("PROVIDER_URI").unwrap_or_else(|_| panic!("PROVIDER_URI not set"));
    let vk_path = "data/vk.json";
    let vk_file = File::open(vk_path).expect("Fail to open data/vk.json");
    let vk: VkNative = serde_json::from_reader(vk_file).expect("Fail to parse vk.json");

    let context = Context {
        qm_url_v1,
        qm_url_v2,
        provider_uri,
        vk,
    };
    rocket::build()
        .manage(context)
        .mount("/", routes![index, batch_verify_v1, batch_verify_v2])
}