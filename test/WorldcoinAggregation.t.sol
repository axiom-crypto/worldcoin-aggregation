// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@axiom-crypto/axiom-std/AxiomTest.sol";

import { WorldcoinAggregation } from "../src/WorldcoinAggregation.sol";

contract WorldcoinAggregationTest is AxiomTest {
    using Axiom for Query;

    struct AxiomInput {
        uint64 blockNumber;
        address addr;
    }

    WorldcoinAggregation public aggregation;
    AxiomInput public input;
    bytes32 public querySchema;

    function setUp() public {
        _createSelectForkAndSetupAxiom("provider");

        input = AxiomInput({ blockNumber: 4_205_938, addr: address(0x8018fe32fCFd3d166E8b4c4E37105318A84BA11b) });
        querySchema = axiomVm.readCircuit("app/axiom/average.circuit.ts");
        aggregation = new WorldcoinAggregation(axiomV2QueryAddress, uint64(block.chainid), querySchema);
    }

    /// @dev Simple demonstration of testing an Axiom client contract using Axiom cheatcodes
    function test_simple_example() public {
        // create a query into Axiom with default parameters
        Query memory q = query(querySchema, abi.encode(input), address(aggregation));

        // send the query to Axiom
        q.send();

        // prank fulfillment of the query, returning the Axiom results
        bytes32[] memory results = q.prankFulfill();
    }
}
