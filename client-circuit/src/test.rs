use crate::mock_test::mock_test_from_path;
use axiom_sdk::Fr;

use ethers::types::U256;

#[test]
fn mock_test_worldcoin_circuit_v1() {
    let output = mock_test_from_path("data/worldcoin_input.json".to_string(), false, "v1");
    let values: Vec<axiom_sdk::Fr> = output.unwrap();
    let vk_hash_hi = "0x0000000000000000000000000000000046e72119ce99272ddff09e0780b472fd";
    let vk_hash_lo = "0x00000000000000000000000000000000c612ca799c245eea223b27e57a5f9cec";

    assert_eq!(values[0], Fr::from_raw(hex_to_u256(vk_hash_hi).0));
    assert_eq!(values[1], Fr::from_raw(hex_to_u256(vk_hash_lo).0));
}

#[test]
fn mock_test_worldcoin_circuit_v2() {
    let output = mock_test_from_path("data/worldcoin_input.json".to_string(), false, "v2");
    let values: Vec<axiom_sdk::Fr> = output.unwrap();
    let vk_hash_hi = "0x0000000000000000000000000000000046e72119ce99272ddff09e0780b472fd";
    let vk_hash_lo = "0x00000000000000000000000000000000c612ca799c245eea223b27e57a5f9cec";

    assert_eq!(values[0], Fr::from_raw(hex_to_u256(vk_hash_hi).0));
    assert_eq!(values[1], Fr::from_raw(hex_to_u256(vk_hash_lo).0));

    let claim_root_hi = "0x00000000000000000000000000000000fc0c0e40f4f84f6d71d1941301705d75";
    let claim_root_lo = "0x000000000000000000000000000000006824a512fa75dae50bfd02e4c45e9c7d";
    assert_eq!(values[6], Fr::from_raw(hex_to_u256(claim_root_hi).0));
    assert_eq!(values[7], Fr::from_raw(hex_to_u256(claim_root_lo).0));
}

#[test]
#[should_panic]
fn mock_test_num_proofs_mismatch() {
    mock_test_from_path("data/num_proofs_mismatch.json".to_string(), true, "v1");
}

#[test]
#[should_panic]
fn mock_test_too_many_proofs() {
    mock_test_from_path("data/too_many_proofs.json".to_string(), true, "v1");
}

#[test]
#[should_panic]
fn mock_test_zero_proof() {
    mock_test_from_path("data/zero_proof.json".to_string(), true, "v1");
}

#[test]
#[should_panic]
fn mock_test_wrong_proof() {
    mock_test_from_path("data/wrong_proof.json".to_string(), true, "v1");
}

fn hex_to_u256(hex: &str) -> U256 {
    U256::from_str_radix(&hex[2..], 16).unwrap()
}
