// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@axiom-crypto/axiom-std/AxiomTest.sol";

import { WorldcoinAggregation } from "../src/WorldcoinAggregation.sol";

contract WorldcoinAggregationTest is AxiomTest {
    using Axiom for Query;

    struct AxiomInput {
        bytes32 vkeyHash;
        uint256 grantId;
        uint256 root;
        uint256 numClaims;
        address[] receivers;
        uint256[] claimedNullifierHashes;
    }

    WorldcoinAggregation public aggregation;
    AxiomInput public input;
    bytes32 public querySchema;
    bytes32 public vkeyHash;
    uint256 public maxNumClaims;

    function setUp() public {
        _createSelectForkAndSetupAxiom("provider");

        address[] memory receivers = new address[](1);
        receivers[0] = address(0x787878);

        uint256[] memory claimedNullifierHashes = new uint256[](1);
        claimedNullifierHashes[0] = 0x4b7790813c37c910b41236334ce9b1841d430e3b4874e89778e1afd0fd3a7b6;

        input = AxiomInput({
            vkeyHash: bytes32(0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef),
            grantId: 31,
            root: 0x1d0372864732dfcd91c18414fd4126e1e38293be237aad4315a026bf23d02717,
            numClaims: 1,
            receivers: receivers,
            claimedNullifierHashes: claimedNullifierHashes
        });
        querySchema = axiomVm.readCircuit("app/axiom/worldcoin.circuit.ts");
        vkeyHash = bytes32(0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef);
        maxNumClaims = 1;
        aggregation =
            new WorldcoinAggregation(axiomV2QueryAddress, uint64(block.chainid), querySchema, vkeyHash, maxNumClaims);
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
