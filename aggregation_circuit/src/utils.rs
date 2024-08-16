use anyhow::{anyhow, Result};
use axiom_eth::{
    halo2_base::safe_types::SafeByte,
    halo2_proofs::{
        plonk::{Circuit, VerifyingKey},
        poly::{commitment::ParamsProver, kzg::commitment::ParamsKZG},
    },
    halo2curves::bn256::{Bn256, Fr, G1Affine},
    rlc::virtual_region::RlcThreadBreakPoints,
    snark_verifier::{
        pcs::kzg::KzgDecidingKey,
        system::halo2::{compile, transcript::evm::EvmTranscript, Config},
        verifier::{plonk::PlonkProof, SnarkVerifier},
    },
    snark_verifier_sdk::{
        halo2::{PoseidonTranscript, POSEIDON_SPEC},
        CircuitExt, NativeLoader, PlonkVerifier, Snark, SHPLONK,
    },
    utils::{
        build_utils::pinning::Halo2CircuitPinning,
        eth_circuit::EthCircuitInstructions,
        keccak::decorator::{RlcKeccakCircuitImpl, RlcKeccakCircuitParams},
    },
    Field,
};

use serde::{Deserialize, Serialize};

use crate::constants::*;

use axiom_eth::{
    keccak::KeccakChip,
    utils::{hilo::HiLo, uint_to_bytes_be},
};

use axiom_eth::halo2_base::{
    gates::{GateInstructions, RangeChip, RangeInstructions},
    utils::biguint_to_fe,
    AssignedValue, Context,
    QuantumCell::Constant,
};

use num_bigint::BigUint;

#[derive(Clone, Default, Debug, Serialize, Deserialize)]
pub struct RlcKeccakCircuitPinning {
    pub params: RlcKeccakCircuitParams,
    pub break_points: RlcThreadBreakPoints,
}

impl Halo2CircuitPinning for RlcKeccakCircuitPinning {
    type CircuitParams = RlcKeccakCircuitParams;
    type BreakPoints = RlcThreadBreakPoints;
    fn new(params: Self::CircuitParams, break_points: Self::BreakPoints) -> Self {
        Self {
            params,
            break_points,
        }
    }
    fn k(&self) -> usize {
        self.params.k()
    }
    fn params(&self) -> Self::CircuitParams {
        self.params.clone()
    }
    fn break_points(&self) -> Self::BreakPoints {
        self.break_points.clone()
    }
}

pub fn get_rlc_keccak_pinning<F: Field, I: EthCircuitInstructions<F>>(
    circuit: &RlcKeccakCircuitImpl<F, I>,
) -> RlcKeccakCircuitPinning {
    let params = circuit.params();
    let break_points = circuit.break_points();
    RlcKeccakCircuitPinning::new(params, break_points)
}

/// This verifies snark with poseidon transcript and **importantly** also checks the
/// kzg accumulator from the public instances, if `snark` is aggregation circuit
///
/// `params` needs to have the same generators as the ones used to generate the snark.
pub fn verify_snark_shplonk(params: &ParamsKZG<Bn256>, snark: &Snark) -> Result<()> {
    let mut transcript =
        PoseidonTranscript::<NativeLoader, &[u8]>::from_spec(snark.proof(), POSEIDON_SPEC.clone());
    let vk: KzgDecidingKey<Bn256> = (params.get_g()[0], params.g2(), params.s_g2()).into();
    let proof: PlonkProof<_, _, SHPLONK> =
        PlonkVerifier::read_proof(&vk, &snark.protocol, &snark.instances, &mut transcript)
            .map_err(|e| anyhow!("Error reading PlonkProof {e:?}"))?;
    PlonkVerifier::verify(&vk, &snark.protocol, &snark.instances, &proof)
        .map_err(|e| anyhow!("PlonkProof did not verify: {e:?}"))?;
    Ok(())
}

/// This verifies snark with poseidon transcript and **importantly** also checks the
/// kzg accumulator from the public instances, if `snark` is aggregation circuit
///
/// `params` needs to have the same generators as the ones used to generate the snark.
pub fn verify_evm_proof_shplonk<C: CircuitExt<Fr>>(
    params: &ParamsKZG<Bn256>,
    vk: &VerifyingKey<G1Affine>,
    proof: &[u8],
    instances: &[Vec<Fr>],
) -> Result<()> {
    let num_instance = instances.iter().map(|x| x.len()).collect();
    let protocol = compile(
        params,
        vk,
        Config::kzg()
            .with_num_instance(num_instance)
            .with_accumulator_indices(C::accumulator_indices()),
    );
    let mut transcript = EvmTranscript::<_, NativeLoader, &[u8], _>::new(proof);
    let dk: KzgDecidingKey<Bn256> = (params.get_g()[0], params.g2(), params.s_g2()).into();
    let proof: PlonkProof<_, _, SHPLONK> =
        PlonkVerifier::read_proof(&dk, &protocol, instances, &mut transcript)
            .map_err(|e| anyhow!("Error reading PlonkProof {e:?}"))?;
    PlonkVerifier::verify(&dk, &protocol, instances, &proof)
        .map_err(|e| anyhow!("PlonkProof did not verify: {e:?}"))?;
    Ok(())
}

pub fn get_vk_hash<F: Field>(
    ctx: &mut Context<F>,
    range: &RangeChip<F>,
    keccak: &KeccakChip<F>,
    vk_bytes: Vec<AssignedValue<F>>,
) -> HiLo<AssignedValue<F>> {
    let vk_bytes: Vec<AssignedValue<F>> = vk_bytes
        .iter()
        .map(|b| {
            let bytes: Vec<AssignedValue<F>> = uint_to_bytes_be(ctx, range, b, 32)
                .iter()
                .map(|sb| *sb.as_ref())
                .collect();
            bytes
        })
        .flatten()
        .collect();
    assert_eq!(vk_bytes.len(), (NUM_BYTES_VK - 1) * 2);

    let vk_hash = keccak.keccak_fixed_len(ctx, vk_bytes);
    HiLo::from_hi_lo([vk_hash.output_hi, vk_hash.output_lo])
}

pub fn get_signal_hash<F: Field>(
    ctx: &mut Context<F>,
    range: &RangeChip<F>,
    keccak: &KeccakChip<F>,
    receiver: &AssignedValue<F>,
) -> AssignedValue<F> {
    let receiver_bytes = uint_to_bytes_be(ctx, range, receiver, 20)
        .iter()
        .map(|b| *b.as_ref())
        .collect();

    let receiver_hash = keccak.keccak_fixed_len(ctx, receiver_bytes);

    // signal_hash is keccak(receiver) >> 8. since keccak(receiver) result is hilo
    // signal_hash_hi = keccak_result_hi >> 8
    // signal_hash_lo = keccak_result_lo >> 8 + (keccak_result_hi_remainder << 16 * 8) >> 8
    let shift = ctx.load_constant(biguint_to_fe(&BigUint::from(2u64).pow((16 - 1) * 8)));
    let (signal_hash_hi, signal_hash_hi_res) =
        range.div_mod(ctx, receiver_hash.output_hi, 256u64, 128);
    let (signal_hash_lo_div, _) = range.div_mod(ctx, receiver_hash.output_lo, 256u64, 128);

    let signal_hash_lo = range
        .gate()
        .mul_add(ctx, signal_hash_hi_res, shift, signal_hash_lo_div);

    range.gate.mul_add(
        ctx,
        signal_hash_hi,
        Constant(range.gate.pow_of_two()[128]),
        signal_hash_lo,
    )
}

// construct a merkle tree from leaves
// return vec is [root, ...[depth 1 nodes], ...[depth 2 nodes], ..., ...[leaves]]
pub fn compute_keccak_merkle_tree<F: Field>(
    ctx: &mut Context<F>,
    range: &RangeChip<F>,
    keccak: &KeccakChip<F>,
    leaves: Vec<HiLo<AssignedValue<F>>>,
) -> Vec<HiLo<AssignedValue<F>>> {
    let len = leaves.len();
    // Also implicit len > 0
    assert!(len.is_power_of_two());
    if len == 1 {
        return leaves;
    }
    let next_level = leaves
        .chunks(2)
        .map(|c| compute_keccak_for_branch_nodes(ctx, range, keccak, &c[0], &c[1]))
        .collect();
    let mut ret: Vec<HiLo<AssignedValue<F>>> =
        compute_keccak_merkle_tree(ctx, range, keccak, next_level);
    ret.extend(leaves);
    ret
}

// compute keecak hash for branch nodes.
pub fn compute_keccak_for_branch_nodes<F: Field>(
    ctx: &mut Context<F>,
    range: &RangeChip<F>,
    keccak: &KeccakChip<F>,
    left_child: &HiLo<AssignedValue<F>>,
    right_child: &HiLo<AssignedValue<F>>,
) -> HiLo<AssignedValue<F>> {
    let mut bytes: Vec<AssignedValue<F>> = Vec::new();
    bytes.extend(
        uint_to_bytes_be(ctx, range, &left_child.hi(), 16)
            .iter()
            .map(|sb| *sb.as_ref()),
    );
    bytes.extend(
        uint_to_bytes_be(ctx, range, &left_child.lo(), 16)
            .iter()
            .map(|sb| *sb.as_ref()),
    );
    bytes.extend(
        uint_to_bytes_be(ctx, range, &right_child.hi(), 16)
            .iter()
            .map(|sb| *sb.as_ref()),
    );
    bytes.extend(
        uint_to_bytes_be(ctx, range, &right_child.lo(), 16)
            .iter()
            .map(|sb| *sb.as_ref()),
    );

    let keccak_hash = keccak.keccak_fixed_len(ctx, bytes);
    HiLo::from_hi_lo([keccak_hash.output_hi, keccak_hash.output_lo])
}
