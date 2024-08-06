use std::fs;

use lazy_static::lazy_static;

use crate::types::VkNative;

pub const MAX_GROTH16_PI: usize = 4;
pub const NUM_FE_VKEY: usize = 25;
pub const NUM_FE_GROTH16_INPUT: usize = 38;
pub const NUM_BYTES_VK: usize = 769;
pub const NUM_LIMBS: usize = 3;
pub const LIMB_BITS: usize = 88;

// batch size of groth16 verifications, we are handling 2 ** INITIAL_DEPTH in one leaf shard
pub const INITIAL_DEPTH: usize = 0;
// extra rounds for evm proof
pub const EXTRA_ROUNDS: usize = 1;

lazy_static! {
    pub static ref VK: VkNative = {
        let file_path = "./data/vk.json"; // Update with your file path
        let json_data = fs::read_to_string(file_path).expect("Unable to read vk");
        serde_json::from_str(&json_data).expect("Unable to parse vk json")
    };
}
