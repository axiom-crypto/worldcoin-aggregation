pub const MAX_GROTH16_PI: usize = 4;
pub const NUM_FE_VKEY: usize = 25;
pub const NUM_FE_GROTH16_INPUT: usize = 38;
pub const NUM_BYTES_VK: usize = 769;
pub const NUM_LIMBS: usize = 3;
pub const LIMB_BITS: usize = 88;

// batch size of groth16 verifications, we are handling 2 ** INITIAL_DEPTH in one leaf shard
pub const INITIAL_DEPTH: usize = 0;
