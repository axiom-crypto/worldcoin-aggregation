// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@axiom-crypto/axiom-std/AxiomTest.sol";

import { WorldcoinAggregationV2 } from "../src/WorldcoinAggregationV2.sol";

contract WorldcoinAggregationV2Test is AxiomTest {
    using Axiom for Query;

    struct AxiomInput {
        bytes32 vkeyHash;
        uint256 grantId;
        uint256 root;
        bytes32 claimsRoot;
    }

    WorldcoinAggregationV2 public aggregation;
    AxiomInput public input;
    bytes32 public querySchema;
    bytes32 public vkeyHash;
    uint256 public logMaxNumClaims;

    function setUp() public {
        _createSelectForkAndSetupAxiom("provider");

        input = AxiomInput({
            vkeyHash: bytes32(0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef),
            grantId: 31,
            root: 0x1d0372864732dfcd91c18414fd4126e1e38293be237aad4315a026bf23d02717,
            claimsRoot: bytes32(0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef)
        });
        querySchema = axiomVm.readCircuit("app/axiom/worldcoinV2.circuit.ts");
        vkeyHash = bytes32(0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef);
        logMaxNumClaims = 1;
        aggregation = new WorldcoinAggregationV2(
            axiomV2QueryAddress, uint64(block.chainid), querySchema, vkeyHash, logMaxNumClaims
        );
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
