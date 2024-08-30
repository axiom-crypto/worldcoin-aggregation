pub mod circuit_factory;
pub mod circuits;
pub mod constants;
pub mod keygen;
pub mod prover;
pub mod scheduler;
pub mod types;
pub mod utils;

pub type CircuitId = String;

#[cfg(feature = "v1")]
pub type WorldcoinLeafInput<F> = crate::circuits::v1::leaf::WorldcoinLeafInput<F>;
#[cfg(feature = "v1")]
pub type WorldcoinLeafCircuit<F> = crate::circuits::v1::leaf::WorldcoinLeafCircuit<F>;
#[cfg(feature = "v1")]
pub type WorldcoinIntermediateAggregationInput =
    crate::circuits::v1::intermediate::WorldcoinIntermediateAggregationInput;
#[cfg(feature = "v1")]
pub type WorldcoinIntermediateAggregationCircuit =
    crate::circuits::v1::intermediate::WorldcoinIntermediateAggregationCircuit;
#[cfg(feature = "v1")]
pub type WorldcoinRootAggregationInput = crate::circuits::v1::root::WorldcoinRootAggregationInput;
#[cfg(feature = "v1")]
pub type WorldcoinRootAggregationCircuit =
    crate::circuits::v1::root::WorldcoinRootAggregationCircuit;

#[cfg(feature = "v2")]
pub type WorldcoinLeafInput<F> = crate::circuits::v2::leaf::WorldcoinLeafInputV2<F>;
#[cfg(feature = "v2")]
pub type WorldcoinLeafCircuit<F> = crate::circuits::v2::leaf::WorldcoinLeafCircuitV2<F>;
#[cfg(feature = "v2")]
pub type WorldcoinIntermediateAggregationInput =
    crate::circuits::v2::intermediate::WorldcoinIntermediateAggregationInputV2;
#[cfg(feature = "v2")]
pub type WorldcoinIntermediateAggregationCircuit =
    crate::circuits::v2::intermediate::WorldcoinIntermediateAggregationCircuitV2;
#[cfg(feature = "v2")]
pub type WorldcoinRootAggregationInput = crate::circuits::v2::root::WorldcoinRootAggregationInputV2;
#[cfg(feature = "v2")]
pub type WorldcoinRootAggregationCircuit =
    crate::circuits::v2::root::WorldcoinRootAggregationCircuitV2;
