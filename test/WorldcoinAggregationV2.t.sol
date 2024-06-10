// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@axiom-crypto/axiom-std/AxiomTest.sol";
import { WorldcoinAggregationV2 } from "../src/WorldcoinAggregationV2.sol";

contract WorldcoinAggregationV2Test is AxiomTest {
    using Axiom for Query;

    struct AxiomInput {
        bytes32 e;
    }

    WorldcoinAggregationV2 public aggregation;
    bytes32 public querySchema;
    bytes32 public vkeyHash;
    uint256 public logMaxNumClaims;

    function setUp() public {
        _createSelectForkAndSetupAxiom("provider");

        querySchema = axiomVm.readRustCircuit(
            "client-circuit/Cargo.toml",
            "client-circuit/data/worldcoin_input.json",
            "client-circuit/data",
            "run_v2_circuit"
        );
        vkeyHash = bytes32(0x46e72119ce99272ddff09e0780b472fdc612ca799c245eea223b27e57a5f9cec);
        logMaxNumClaims = 4;
        aggregation = new WorldcoinAggregationV2(
            axiomV2QueryAddress, uint64(block.chainid), querySchema, vkeyHash, logMaxNumClaims
        );
    }
    /// @dev Simple demonstration of testing an Axiom client contract using Axiom cheatcodes

    function test_simple_example() public {
        // create a query into Axiom with default parameters
        Query memory q = query(querySchema, "", address(aggregation));

        // send the query to Axiom
        q.send();

        // prank fulfillment of the query, returning the Axiom results
        q.prankFulfill();
    }
}
