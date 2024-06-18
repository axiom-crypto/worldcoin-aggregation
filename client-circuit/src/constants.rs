use std::env;

#[cfg(feature = "max_proofs_16")]
pub const MAX_PROOFS: usize = 16;

#[cfg(feature = "max_proofs_128")]
pub const MAX_PROOFS: usize = 128;

#[cfg(feature = "max_proofs_512")]
pub const MAX_PROOFS: usize = 128;

#[cfg(feature = "max_proofs_1024")]
pub const MAX_PROOFS: usize = 1024;

#[cfg(feature = "max_proofs_8192")]
pub const MAX_PROOFS: usize = 8192;

pub const MAX_GROTH16_PI: usize = 4;
pub const NUM_FE_VKEY: usize = 25;
pub const NUM_FE_GROTH16_INPUT: usize = 38;
pub const NUM_BYTES_VK: usize = 769;
