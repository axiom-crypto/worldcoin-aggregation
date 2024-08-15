use std::{
    collections::HashMap,
    fmt::Debug,
    fs::{self, File},
    hash::{DefaultHasher, Hash, Hasher},
    io::BufReader,
    ops::Deref,
    path::{Path, PathBuf},
    sync::Arc,
};

use anyhow::{Context, Result};
use axiom_eth::{
    halo2_base::{
        gates::circuit::CircuitBuilderStage,
        halo2_proofs::{
            halo2curves::bn256::{Bn256, Fr, G1Affine},
            plonk::ProvingKey,
            poly::kzg::commitment::ParamsKZG,
        },
    },
    halo2_proofs::{plonk::Circuit, poly::commitment::Params},
    snark_verifier_sdk::evm::{encode_calldata, gen_evm_proof_shplonk},
    snark_verifier_sdk::{self, halo2::gen_snark_shplonk, CircuitExt},
    utils::snark_verifier::EnhancedSnark,
};

use clap::Parser;
use ethers::utils::hex;
use rocket::tokio;
use serde::{de::DeserializeOwned, Serialize};
use tokio::sync::{Mutex, RwLock};

use crate::{types::InvalidInputContext, CircuitId};

/// This is an identifier for a specific proof request, consisting of the circuit type together with any data necessary to create the circuit inputs.
/// It should be thought of as a node in a DAG (directed acyclic graph), where the edges specify previous SNARKs this one depends on.
pub trait ProofRequest: Clone + Debug + Send + Serialize {
    type Circuit: CircuitExt<Fr>;
    // Not using CircuitPinningInstructions for more control / avoid rust orphan rule
    type Pinning: Clone + DeserializeOwned;
    const AGG_VKEY_HASH_IDX: Option<usize> = None;

    fn get_k(pinning: &Self::Pinning) -> u32;

    fn proof_id(&self) -> String;

    fn hash(&self) -> u64 {
        let json_string = serde_json::to_string(&self).expect("Failed to serialize to JSON");

        let mut hasher = DefaultHasher::new();
        json_string.hash(&mut hasher);
        hasher.finish()
    }

    fn build(
        self,
        stage: CircuitBuilderStage,
        pinning: Self::Pinning,
        kzg_params: Option<&ParamsKZG<Bn256>>,
    ) -> Result<Self::Circuit>;

    fn prover_circuit(
        self,
        pinning: Self::Pinning,
        kzg_params: Option<&ParamsKZG<Bn256>>,
    ) -> Result<Self::Circuit> {
        self.build(CircuitBuilderStage::Prover, pinning, kzg_params)
    }
}

#[derive(Parser, Clone, Debug)]
pub struct ProverConfig {
    #[arg(long = "circuit-data-dir")]
    pub circuit_data_dir: PathBuf,
    #[arg(long = "srs-dir")]
    pub srs_dir: PathBuf,
    /// Cache snarks
    #[arg(long = "out-dir")]
    pub out_dir: Option<PathBuf>,
}

pub struct ProvingServerState {
    pub config: ProverConfig,
    proof_mutex: Mutex<()>,
    /// We always keep srs in memory
    srs: RwLock<HashMap<u32, Arc<ParamsKZG<Bn256>>>>,
    pinning: RwLock<HashMap<CircuitId, Arc<serde_json::Value>>>,
    pk: RwLock<HashMap<CircuitId, Arc<ProvingKey<G1Affine>>>>,
}

impl ProvingServerState {
    pub fn new(config: ProverConfig) -> Self {
        Self {
            config,
            proof_mutex: Default::default(),
            srs: Default::default(),
            pinning: Default::default(),
            pk: Default::default(),
        }
    }
    /// Clears everything stored in memory
    pub async fn reset(&self) {
        self.srs.write().await.clear();
        self.pinning.write().await.clear();
        self.pk.write().await.clear();
    }
    pub fn circuit_data_dir(&self) -> &Path {
        &self.config.circuit_data_dir
    }
    pub fn srs_dir(&self) -> &Path {
        &self.config.srs_dir
    }
    pub fn out_dir(&self) -> Option<&Path> {
        self.config.out_dir.as_deref()
    }

    pub async fn acquire_proof_mutex(&self) -> tokio::sync::MutexGuard<'_, ()> {
        self.proof_mutex.lock().await
    }
    pub async fn get_srs(&self, k: u32) -> anyhow::Result<Arc<ParamsKZG<Bn256>>> {
        if let Some(srs) = self.srs.read().await.get(&k) {
            return Ok(srs.clone());
        }
        let srs = Arc::new(self.read_srs(k).await?);
        self.srs.write().await.insert(k, srs.clone());
        Ok(srs)
    }
    pub async fn get_pinning(&self, circuit_id: &str) -> anyhow::Result<Arc<serde_json::Value>> {
        if let Some(pinning) = self.pinning.read().await.get(circuit_id) {
            return Ok(pinning.clone());
        }
        let pinning = Arc::new(self.read_pinning(circuit_id).await?);
        self.pinning
            .write()
            .await
            .insert(circuit_id.to_owned(), pinning.clone());
        Ok(pinning)
    }

    pub async fn build_circuit<R: ProofRequest>(
        &self,
        circuit_id: &str,
        req: R,
    ) -> Result<(Arc<ParamsKZG<Bn256>>, Arc<ProvingKey<G1Affine>>, R::Circuit)> {
        let pinning_json = self.get_pinning(circuit_id).await?;
        let pinning: R::Pinning = serde_json::from_value(pinning_json.deref().clone())?;

        let k = R::get_k(&pinning);
        let kzg_params = &self.get_srs(k).await?;

        let circuit = req
            .prover_circuit(pinning, Some(kzg_params))
            .context(InvalidInputContext)?;
        let pk_lock = self.pk.read().await;
        let pk_option = pk_lock.get(circuit_id).cloned(); // Note: clone to release the read lock
        drop(pk_lock);
        let pk = if let Some(pk) = pk_option {
            pk
        } else {
            let pk_path = self.pkey_path(circuit_id);
            let pk = snark_verifier_sdk::read_pk_with_capacity::<R::Circuit>(
                128 * 1024 * 1024, /* 128 MB */
                &pk_path,
                circuit.params(),
            )?;
            log::debug!("read pk from {}", pk_path.display());
            let pk = Arc::new(pk);
            self.pk
                .write()
                .await
                .insert(circuit_id.to_owned(), pk.clone());

            log::debug!("Returning pk");

            pk
        };

        Ok((kzg_params.clone(), pk, circuit))
    }

    pub async fn get_snark<R: ProofRequest>(
        &self,
        circuit_id: &str,
        req: R,
    ) -> Result<EnhancedSnark> {
        let _mutex_guard = self.acquire_proof_mutex().await;
        log::info!("get_snark:circuit_id={circuit_id}");
        let snark_path = self.snark_path(circuit_id, &req);

        log::debug!("build circuit for proof_id={}", req.proof_id());
        log::debug!("circuit_id={}, request={:?}", circuit_id, req);
        let (kzg_params, pk, circuit) = self.build_circuit(circuit_id, req).await?;
        log::debug!("gen_snark start");

        let snark = gen_snark_shplonk(&kzg_params, &pk, circuit, snark_path);

        log::debug!("gen_snark end");
        #[cfg(debug_assertions)]
        {
            crate::utils::verify_snark_shplonk(&kzg_params, &snark)?;
        }

        Ok(EnhancedSnark {
            inner: snark,
            agg_vk_hash_idx: R::AGG_VKEY_HASH_IDX,
        })
    }

    pub async fn get_evm_proof<R: ProofRequest>(&self, circuit_id: &str, req: R) -> Result<String> {
        let _mutex_guard = self.acquire_proof_mutex().await;
        log::info!("get_evm_proof:circuit_id={circuit_id}");
        let evm_proof_path = self.evm_proof_path(circuit_id, &req);
        // check fs cache
        if let Some(Ok(evm_proof)) = evm_proof_path.as_ref().map(fs::read_to_string) {
            log::debug!("evm_proof found at {:?}", evm_proof_path);
            // proof is serialized as a hex string
            return Ok(evm_proof);
        }
        log::debug!("build circuit for proof_id={}", req.proof_id());
        let (kzg_params, pk, circuit) = self.build_circuit(circuit_id, req).await?;
        log::debug!("gen_evm_proof start");
        let instances = circuit.instances();
        let proof = gen_evm_proof_shplonk(&kzg_params, &pk, circuit, instances.clone());
        log::debug!("gen_evm_proof end");
        #[cfg(debug_assertions)]
        {
            crate::utils::verify_evm_proof_shplonk::<R::Circuit>(
                &kzg_params,
                pk.get_vk(),
                &proof,
                &instances,
            )?;
        }
        let evm_proof = encode_calldata(&instances, &proof);
        let evm_proof = hex::encode(evm_proof);
        if let Some(path) = evm_proof_path {
            fs::write(&path, &evm_proof)
                .map_err(anyhow::Error::from)
                .with_context(|| format!("Failed to write evm_proof to {}", path.display()))?;
        }

        Ok(evm_proof)
    }

    // === Boring fs stuff ===
    pub fn pinning_path(&self, cid: &str) -> PathBuf {
        self.circuit_data_dir().join(cid).with_extension("json")
    }
    pub fn pkey_path(&self, cid: &str) -> PathBuf {
        self.circuit_data_dir().join(cid).with_extension("pk")
    }
    pub fn snark_path<R: ProofRequest>(&self, cid: &str, req: &R) -> Option<PathBuf> {
        self.out_dir()
            .map(|out_dir| out_dir.join(format!("{}_{}.snark", req.proof_id(), cid)))
    }
    pub fn evm_proof_path<R: ProofRequest>(&self, cid: &str, req: &R) -> Option<PathBuf> {
        self.out_dir()
            .map(|out_dir| out_dir.join(format!("{}_{}.evm_proof", req.proof_id(), cid)))
    }

    async fn read_srs(&self, k: u32) -> anyhow::Result<ParamsKZG<Bn256>> {
        let srs_path = self.srs_dir().join(format!("kzg_bn254_{k}.srs"));
        let mut reader = BufReader::new(
            File::open(&srs_path)
                .with_context(|| format!("Failed to open {}", srs_path.display()))?,
        );
        ParamsKZG::<Bn256>::read(&mut reader).map_err(anyhow::Error::from)
    }
    async fn read_pinning(&self, circuit_id: &str) -> anyhow::Result<serde_json::Value> {
        let pinning_path = self.pinning_path(circuit_id);
        serde_json::from_reader(
            File::open(&pinning_path)
                .with_context(|| format!("Failed to open {}", pinning_path.display()))?,
        )
        .map_err(anyhow::Error::from)
    }
}
