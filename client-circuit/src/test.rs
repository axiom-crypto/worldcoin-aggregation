use crate::mock_test::mock_test_from_path;

#[test]
fn mock_test_worldcoin_circuit() {
    mock_test_from_path("data/worldcoin_input.json".to_string(), false);
}

#[test]
#[should_panic]
fn mock_test_num_proofs_mismatch() {
    mock_test_from_path("data/num_proofs_mismatch.json".to_string(), true);
}

#[test]
#[should_panic]
fn mock_test_too_many_proofs() {
    mock_test_from_path("data/too_many_proofs.json".to_string(), true);
}

#[test]
#[should_panic]
fn mock_test_zero_proof() {
    mock_test_from_path("data/zero_proof.json".to_string(), true);
}

#[test]
#[should_panic]
fn mock_test_wrong_proof() {
    mock_test_from_path("data/wrong_proof.json".to_string(), true);
}
