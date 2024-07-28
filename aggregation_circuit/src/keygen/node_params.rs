use axiom_eth::{
    halo2_base::gates::flex_gate::MultiPhaseThreadBreakPoints,
    halo2curves::bn256::{Bn256, G1Affine},
    rlc::virtual_region::RlcThreadBreakPoints,
    snark_verifier::{pcs::kzg::KzgDecidingKey, verifier::plonk::PlonkProtocol},
    utils::{
        build_utils::pinning::aggregation::{GenericAggParams, GenericAggPinning},
        keccak::decorator::RlcKeccakCircuitParams,
        snark_verifier::{AggregationCircuitParams, Base64Bytes},
    },
};
use serde::{Deserialize, Serialize};
use serde_with::serde_as;

/// Circuit parameters by node type
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub struct NodeParams {
    /// Type of the node in the aggregation tree.
    pub node_type: NodeType,
    /// The maximum number of claims at this level of the tree is 2<sup>depth</sup>.
    pub depth: usize,
    /// The leaf layer of the aggregation starts with max number of proofs equal to 2<sup>initial_depth</sup>.
    pub initial_depth: usize,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize, PartialOrd, Ord)]
pub enum NodeType {
    Leaf,
    Intermediate,
    Root,
    /// The block number range must fit within the specified max depth. `Evm(round)` performs `round + 1`
    /// rounds of SNARK verification on the final `Root` circuit
    Evm(usize),
}

impl NodeParams {
    pub fn new(node_type: NodeType, depth: usize, initial_depth: usize) -> Self {
        assert!(depth >= initial_depth);
        Self {
            node_type,
            depth,
            initial_depth,
        }
    }

    pub fn child(&self) -> Option<Self> {
        match self.node_type {
            NodeType::Leaf => None,
            NodeType::Intermediate | NodeType::Root => {
                assert!(self.depth > self.initial_depth);
                if self.depth == self.initial_depth + 1 {
                    Some(Self::new(
                        NodeType::Leaf,
                        self.initial_depth,
                        self.initial_depth,
                    ))
                } else {
                    Some(Self::new(
                        NodeType::Intermediate,
                        self.depth - 1,
                        self.initial_depth,
                    ))
                }
            }
            NodeType::Evm(round) => {
                if round == 0 {
                    let node_type = if self.depth == self.initial_depth {
                        NodeType::Leaf
                    } else {
                        NodeType::Root
                    };
                    Some(Self::new(node_type, self.depth, self.initial_depth))
                } else {
                    Some(Self::new(
                        NodeType::Evm(round - 1),
                        self.depth,
                        self.initial_depth,
                    ))
                }
            }
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct PinningLeaf {
    pub num_instance: Vec<usize>,
    pub params: RlcKeccakCircuitParams,
    pub break_points: RlcThreadBreakPoints,
    /// g1 generator, g2 generator, s_g2 (s is generator of trusted setup).
    /// Together with domain size `2^k`, this commits to the trusted setup used.
    /// This is all that's needed to verify the final ecpairing check on the KZG proof.
    pub dk: KzgDecidingKey<Bn256>,
}

#[serde_as]
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct PinningIntermediate {
    /// Configuration parameters
    pub params: AggregationCircuitParams,
    /// PlonkProtocol of the children
    #[serde_as(as = "Vec<Base64Bytes>")]
    pub to_agg: Vec<PlonkProtocol<G1Affine>>,
    /// Number of instances in each instance column
    pub num_instance: Vec<usize>,
    /// Break points. Should only have phase0, so MultiPhase is extraneous.
    pub break_points: MultiPhaseThreadBreakPoints,
    /// g1 generator, g2 generator, s_g2 (s is generator of trusted setup).
    /// Together with domain size `2^k`, this commits to the trusted setup used.
    /// This is all that's needed to verify the final ecpairing check on the KZG proof.
    pub dk: KzgDecidingKey<Bn256>,
}

#[serde_as]
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct PinningRoot {
    /// Configuration parameters
    pub params: AggregationCircuitParams,
    /// PlonkProtocol of the children
    #[serde_as(as = "Vec<Base64Bytes>")]
    pub to_agg: Vec<PlonkProtocol<G1Affine>>,
    /// Number of instances in each instance column
    pub num_instance: Vec<usize>,
    /// Break points. Should only have phase0, so MultiPhase is extraneous.
    pub break_points: MultiPhaseThreadBreakPoints,
    /// g1 generator, g2 generator, s_g2 (s is generator of trusted setup).
    /// Together with domain size `2^k`, this commits to the trusted setup used.
    /// This is all that's needed to verify the final ecpairing check on the KZG proof.
    pub dk: KzgDecidingKey<Bn256>,
}

pub type PinningEvm = GenericAggPinning<GenericAggParams>;
