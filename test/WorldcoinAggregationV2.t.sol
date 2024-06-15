// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Axiom, Query, FulfillCallbackArgs } from "@axiom-crypto/axiom-std/AxiomTest.sol";
import { IAxiomV2Client } from "@axiom-crypto/v2-periphery/interfaces/client/IAxiomV2Client.sol";

import { WorldcoinAggregationV2Helper } from "./helpers/WorldcoinAggregationV2Helper.sol";

import { IERC20 } from "../src/interfaces/IERC20.sol";
import { WorldcoinAggregationV2 } from "../src/WorldcoinAggregationV2.sol";

using Axiom for Query;

/// @dev For the V2 test, the claiming process involves submitting a merkle
/// proof. The leaves for this merkle tree are determined by
/// `abi.encodePacked(address(reciever), bytes32(nullifierHash))`. All leaves of
/// the tree must be filled to `maxNumClaims`. Empty leaves will be filled with
/// `abi.encodePacked(address(0), bytes32(0))`. This test will use the
/// `client-circuit/data/worldcoin_input.json` that has two receivers. So the
/// leaves array will look something like:
/// [
///  abi.encodePacked(address(reciever1), bytes32(nullifierHash1)),
///  abi.encodePacked(address(reciever2), bytes32(nullifierHash2)),
///  abi.encodePacked(address(0), bytes32(0)),
///  ...,
///  abi.encodePacked(address(0), bytes32(0))
/// ]
/// with a total 16 elements in the array. For the sake of simplicity, the
/// proofs for the two users will be hardcoded within this contract.
contract WorldcoinAggregationV2_Test is WorldcoinAggregationV2Helper {
    function test_simpleExample() public {
        // create a query into Axiom with default parameters
        Query memory q = query(querySchema, "", address(aggregation));

        // send the query to Axiom
        q.send();

        // prank fulfillment of the query, returning the Axiom results
        (bytes32 _vkeyHash, uint256 _grantId, uint256 _root, bytes32 _claimsRoot) = _parseResults(q.prankFulfill());

        assertEq(_vkeyHash, vkeyHash, "vkeyHash mismatch");
        assertEq(_grantId, grantId, "grantId mismatch");
        assertEq(_root, root, "root mismatch");
        assertEq(_claimsRoot, claimsRoot, "claimsRoot mismatch");

        for (uint256 i = 0; i != numClaims; ++i) {
            aggregation.claim(grantId, root, receivers[i], nullifierHashes[i], receiverProofs[i]);

            assertEq(IERC20(wldToken).balanceOf(receivers[i]), 3e18, "Unexpected balance");
        }
    }

    function testFuzz_efficientPackedhash(address a, bytes32 b) public {
        bytes32 result = aggregation.efficientPackedHash(a, b);
        bytes32 expected = keccak256(abi.encodePacked(a, b));
        assertEq(result, expected, "efficientPackedHash mismatch");
    }

    function testFuzz_efficientHash(bytes32 a, bytes32 b) public {
        bytes32 result = aggregation.efficientHash(a, b);
        bytes32 expected = keccak256(abi.encodePacked(a, b));
        assertEq(result, expected, "efficientHash mismatch");
    }

    function testFuzz_unsafeProofAccess(WorldcoinAggregationV2.ProofElement[] calldata array, uint256 index) public {
        vm.assume(array.length != 0);
        index = bound(index, 0, array.length - 1);

        (bytes32 resultLeaf, bool resultIsLeft) = aggregation.unsafeProofAccess(array, index);

        bytes32 expectedLeaf = array[index].leaf;
        bool expectedIsLeft = array[index].isLeft;

        assertEq(resultLeaf, expectedLeaf, "unsafeProofAccess leaf mismatch");
        assertEq(resultIsLeft, expectedIsLeft, "unsafeProofAccess isLeft mismatch");
    }

    function testFuzz_unsafeBytes32Access(bytes32[] calldata array, uint256 index) public {
        vm.assume(array.length != 0);
        index = bound(index, 0, array.length - 1);

        bytes32 result = aggregation.unsafeBytes32Access(array, index);
        bytes32 expected = array[index];
        assertEq(result, expected, "unsafeBytes32Access mismatch");
    }
}

contract WorldcoinAggregationV2_RevertTest is WorldcoinAggregationV2Helper {
    FulfillCallbackArgs args;
    Query q;

    function setUp() public override {
        super.setUp();

        // create a query into Axiom with default parameters
        q = query(querySchema, "", address(aggregation));

        // send the query to Axiom
        q.send();

        args = q.axiomVm.fulfillCallbackArgs(
            q.querySchema, q.input, q.callbackTarget, q.callbackExtraData, q.feeData, q.caller
        );
    }

    function test_RevertWhen_sourceChainIdNotMatching() public {
        vm.prank(axiomV2QueryAddress);

        vm.expectRevert(WorldcoinAggregationV2.SourceChainIdNotMatching.selector);
        IAxiomV2Client(aggregation).axiomV2Callback({
            sourceChainId: args.sourceChainId >> 1,
            caller: args.caller,
            querySchema: args.querySchema,
            queryId: args.queryId,
            extraData: args.callbackExtraData,
            axiomResults: args.axiomResults
        });
    }

    function test_RevertWhen_invalidQuerySchema() public {
        vm.prank(axiomV2QueryAddress);

        vm.expectRevert(WorldcoinAggregationV2.InvalidQuerySchema.selector);
        IAxiomV2Client(aggregation).axiomV2Callback({
            sourceChainId: args.sourceChainId,
            caller: args.caller,
            querySchema: args.querySchema >> 1,
            queryId: args.queryId,
            extraData: args.callbackExtraData,
            axiomResults: args.axiomResults
        });
    }

    function test_RevertWhen_invalidNumberOfResults() public {
        vm.prank(axiomV2QueryAddress);

        bytes32[] memory results = new bytes32[](0);

        vm.expectRevert(WorldcoinAggregationV2.InvalidNumberOfResults.selector);
        IAxiomV2Client(aggregation).axiomV2Callback({
            sourceChainId: args.sourceChainId,
            caller: args.caller,
            querySchema: args.querySchema,
            queryId: args.queryId,
            extraData: args.callbackExtraData,
            axiomResults: results
        });
    }

    function test_RevertWhen_invalidVkeyHash() public {
        vm.prank(axiomV2QueryAddress);

        args.axiomResults[0] = bytes32(0);

        vm.expectRevert(WorldcoinAggregationV2.InvalidVkeyHash.selector);
        IAxiomV2Client(aggregation).axiomV2Callback({
            sourceChainId: args.sourceChainId,
            caller: args.caller,
            querySchema: args.querySchema,
            queryId: args.queryId,
            extraData: args.callbackExtraData,
            axiomResults: args.axiomResults
        });
    }

    function test_RevertWhen_invalidGrantId() public {
        vm.prank(axiomV2QueryAddress);

        args.axiomResults[1] = 0;

        vm.expectRevert(WorldcoinAggregationV2.InvalidGrantId.selector);
        IAxiomV2Client(aggregation).axiomV2Callback({
            sourceChainId: args.sourceChainId,
            caller: args.caller,
            querySchema: args.querySchema,
            queryId: args.queryId,
            extraData: args.callbackExtraData,
            axiomResults: args.axiomResults
        });
    }

    function test_RevertWhen_invalidRoot() public {
        vm.prank(axiomV2QueryAddress);

        args.axiomResults[2] = 0;

        vm.expectRevert();
        IAxiomV2Client(aggregation).axiomV2Callback({
            sourceChainId: args.sourceChainId,
            caller: args.caller,
            querySchema: args.querySchema,
            queryId: args.queryId,
            extraData: args.callbackExtraData,
            axiomResults: args.axiomResults
        });
    }

    function test_RevertWhen_claimingWithInvalidGrantId() public {
        q.prankFulfill();

        vm.expectRevert(WorldcoinAggregationV2.InvalidGrantId.selector);
        aggregation.claim(0, root, receivers[0], nullifierHashes[0], receiverProofs[0]);
    }

    function test_RevertWhen_doubleClaiming() public {
        q.prankFulfill();
        aggregation.claim(grantId, root, receivers[0], nullifierHashes[0], receiverProofs[0]);

        vm.expectRevert(WorldcoinAggregationV2.NullifierHashAlreadyUsed.selector);
        aggregation.claim(grantId, root, receivers[0], nullifierHashes[0], receiverProofs[0]);
    }

    function test_RevertWhen_invalidReceiverClaiming() public {
        q.prankFulfill();

        vm.expectRevert(WorldcoinAggregationV2.InvalidReceiver.selector);
        aggregation.claim(grantId, root, address(0), nullifierHashes[0], receiverProofs[0]);
    }

    function test_RevertWhen_invalidMerkleProofLength() public {
        q.prankFulfill();

        vm.expectRevert(WorldcoinAggregationV2.InvalidMerkleProofLength.selector);
        aggregation.claim(grantId, root, receivers[0], nullifierHashes[0], new WorldcoinAggregationV2.ProofElement[](0));
    }

    function test_RevertWhen_invalidMerkleProof() public {
        q.prankFulfill();

        WorldcoinAggregationV2.ProofElement[] memory invalidProof =
            new WorldcoinAggregationV2.ProofElement[](logMaxNumClaims);

        vm.expectRevert(WorldcoinAggregationV2.InvalidMerkleProof.selector);
        aggregation.claim(grantId, root, receivers[0], nullifierHashes[0], invalidProof);
    }
}
