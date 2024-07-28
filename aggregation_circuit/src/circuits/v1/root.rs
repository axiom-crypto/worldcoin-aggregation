//! The root of the aggregation tree.
//! An [WorldcoinRootAggregationCircuit] can aggregate either:
//! - two [WorldcoinLeafnCircuit]s (if `max_depth == initial_depth + 1`) or
//! - two [WorldcoinIntermediateAggregationCircuit]s.
//!
//! The difference between Intermediate and Root aggregation circuits is that they expose different public outputs

use anyhow::{bail, Result};
use axiom_eth::{
    halo2_base::gates::circuit::CircuitBuilderStage,
    halo2_proofs::poly::{commitment::ParamsProver, kzg::commitment::ParamsKZG},
    halo2curves::bn256::Bn256,
    snark_verifier_sdk::{
        halo2::aggregation::{AggregationCircuit, Svk},
        Snark,
    },
    utils::{
        build_utils::aggregation::CircuitMetadata,
        snark_verifier::{get_accumulator_indices, AggregationCircuitParams, NUM_FE_ACCUMULATOR},
    },
};

use super::intermediate::WorldcoinIntermediateAggregationInput;
pub struct WorldcoinRootAggregationCircuit(pub AggregationCircuit);

#[derive(Clone, Debug)]
pub struct WorldcoinRootAggregationInput {
    pub inner: WorldcoinIntermediateAggregationInput,
    /// Succinct verifying key (generator of KZG trusted setup) should match `inner.snarks`
    pub svk: Svk,
    prev_acc_indices: Vec<Vec<usize>>,
}

impl WorldcoinRootAggregationInput {
    /// `snarks` should be exactly two snarks of either
    /// - `WorldcoinLeafnCircuit` if `max_depth == initial_depth + 1` or
    /// - `WorldcoinIntermediateAggregationCircuit` otherwise
    ///
    /// We only need the generator `kzg_params.get_g()[0]` to match that of the trusted setup used
    /// in the creation of `snarks`.
    pub fn new(
        snarks: Vec<Snark>,
        num_proofs: u32,
        max_depth: usize,
        initial_depth: usize,
        kzg_params: &ParamsKZG<Bn256>,
    ) -> Result<Self> {
        let svk = kzg_params.get_g()[0].into();
        let prev_acc_indices = get_accumulator_indices(&snarks);
        if max_depth == initial_depth + 1
            && prev_acc_indices.iter().any(|indices| !indices.is_empty())
        {
            bail!("Snarks to be aggregated must not have accumulators: they should come from WorldcoinLeafCircuit");
        }
        if max_depth > initial_depth + 1
            && prev_acc_indices
                .iter()
                .any(|indices| indices.len() != NUM_FE_ACCUMULATOR)
        {
            bail!("Snarks to be aggregated must all be WorldcoinIntermediateAggregationCircuits");
        }
        let inner = WorldcoinIntermediateAggregationInput::new(
            snarks,
            num_proofs,
            max_depth,
            initial_depth,
        );
        Ok(Self {
            inner,
            svk,
            prev_acc_indices,
        })
    }
}

impl WorldcoinRootAggregationInput {
    pub fn build(
        self,
        stage: CircuitBuilderStage,
        circuit_params: AggregationCircuitParams,
        kzg_params: &ParamsKZG<Bn256>,
    ) -> Result<WorldcoinRootAggregationCircuit> {
        let WorldcoinIntermediateAggregationInput {
            max_depth,
            initial_depth,
            num_proofs,
            snarks: _,
        } = self.inner.clone();

        log::info!(
            "New WorldcoinRootAggregationCircuit | num_proofs: {num_proofs} | max_depth: {max_depth} | initial_depth: {initial_depth}"
        );
        let aggregation_circuit = self
            .inner
            .build_aggregation_circuit(stage, circuit_params, kzg_params, true)
            .unwrap();
        Ok(WorldcoinRootAggregationCircuit(aggregation_circuit))
    }
}

impl CircuitMetadata for WorldcoinRootAggregationInput {
    const HAS_ACCUMULATOR: bool = true;

    fn num_instance(&self) -> Vec<usize> {
        vec![NUM_FE_ACCUMULATOR + 5 + 2 * (1 << self.inner.max_depth)]
    }
}
