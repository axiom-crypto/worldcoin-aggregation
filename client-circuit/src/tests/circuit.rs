use crate::mock_test::mock_test_from_path;

#[test]
fn mock_test_snapshot_circuit() {
    mock_test_from_path("data/worldcoin_input.json".to_string(), false);
}
