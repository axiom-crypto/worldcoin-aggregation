use std::fs;

use ethers::utils::keccak256;
use lazy_static::lazy_static;

use crate::types::VkNative;

pub const MAX_GROTH16_PI: usize = 4;
pub const NUM_FE_VKEY: usize = 25;
pub const NUM_FE_GROTH16_INPUT: usize = 38;
pub const NUM_BYTES_VK: usize = 769;
pub const NUM_LIMBS: usize = 3;
pub const LIMB_BITS: usize = 88;

// batch size of groth16 verifications, we are handling 2 ** INITIAL_DEPTH in one leaf shard
pub const INITIAL_DEPTH: usize = 3;
// extra rounds for evm proof
pub const EXTRA_ROUNDS: usize = 1;

lazy_static! {
    pub static ref VK: VkNative = {
        let file_path = "./data/vk.json";
        let json_data = fs::read_to_string(file_path).expect("Unable to read vk");
        serde_json::from_str(&json_data).expect("Unable to parse vk json")
    };

    pub static ref DUMMY_CLAIM_ROOTS: Vec<[u8; 32]> = {
        let max_depth = 13; // 8192
        // grant_id (32bytes) + receiver (20) + nullifier_hash (32)
        let dummy_leaf = [0u8; 84];
        let mut roots = Vec::with_capacity(max_depth + 1);

        // Initialize the first level (leaf level)
        let mut current_level = vec![keccak256(&dummy_leaf); 1];

        // Store the root at depth 0
        roots.push(current_level[0]);

        // Iteratively compute and store roots for each depth
        for _ in 1..=max_depth {
            // Compute the next level up
            current_level = current_level
                .iter()
                .flat_map(|hash| {
                    let mut concatenated = [0u8; 64];
                    concatenated[..32].copy_from_slice(hash);
                    concatenated[32..].copy_from_slice(hash); // Duplicate the hash to simulate sibling pair
                    [keccak256(&concatenated)].into_iter()
                })
                .collect();

            // Store the computed root for this depth
            roots.push(current_level[0]);
        }

        roots
    };

}
