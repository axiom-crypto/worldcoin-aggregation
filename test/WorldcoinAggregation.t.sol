// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Axiom, Query, FulfillCallbackArgs } from "@axiom-crypto/axiom-std/AxiomVm.sol";
import { IAxiomV2Client } from "@axiom-crypto/v2-periphery/interfaces/client/IAxiomV2Client.sol";

import { WorldcoinAggregationHelper } from "./helpers/WorldcoinAggregationHelper.sol";
import { IERC20 } from "../src/interfaces/IERC20.sol";
import { WorldcoinAggregation } from "../src/WorldcoinAggregation.sol";
import { IGrant } from "../src/interfaces/IGrant.sol";

using Axiom for Query;

contract WorldcoinAggregation_Test is WorldcoinAggregationHelper {
    function test_simpleExample() public {
        // create a query into Axiom with default parameters
        Query memory q = query(querySchema, "", address(aggregation));

        // send the query to Axiom
        q.send();

        // prank fulfillment of the query, returning the Axiom results
        (
            bytes32 _vkeyHash,
            uint256 _grantId,
            uint256 _root,
            uint256 numClaims,
            address[] memory _receivers,
            bytes32[] memory _nullifierHashes
        ) = _parseResults(q.prankFulfill());

        assertEq(_vkeyHash, vkeyHash, "vkeyHash mismatch");
        assertEq(_grantId, grantId, "grantId mismatch");
        assertEq(_root, root, "root mismatch");
        assertLe(numClaims, maxNumClaims, "numClaims exceeds maxNumClaims");

        for (uint256 i = 0; i < numClaims; ++i) {
            assertEq(_receivers[i], receivers[i], "receiver mismatch");
            assertEq(_nullifierHashes[i], nullifierHashes[i], "nullifierHash mismatch");

            assertEq(
                IERC20(wldToken).balanceOf(_receivers[i]),
                mockGrant.getAmount(mockGrant.calculateId(block.timestamp)),
                "claim failed"
            );
        }
    }

    function test_skipFaultyGrant() public {
        // create a query into Axiom with default parameters
        Query memory q = query(querySchema, "", address(aggregation));

        // send the query to Axiom
        q.send();

        FulfillCallbackArgs memory args = q.axiomVm.fulfillCallbackArgs(
            q.querySchema, q.input, q.callbackTarget, q.callbackExtraData, q.feeData, q.caller
        );

        // This is the address of the first receiver
        args.axiomResults[4] = bytes32(0);

        uint256 receiver1BalanceBefore = IERC20(wldToken).balanceOf(address(0));

        vm.prank(axiomV2QueryAddress);
        IAxiomV2Client(aggregation).axiomV2Callback({
            sourceChainId: args.sourceChainId,
            caller: args.caller,
            querySchema: args.querySchema,
            queryId: args.queryId,
            extraData: args.callbackExtraData,
            axiomResults: args.axiomResults
        });

        uint256 receiver1BalanceAfter = IERC20(wldToken).balanceOf(address(0));

        (,,,, address[] memory _receivers,) = _parseResults(args.axiomResults);

        assertEq(receiver1BalanceBefore, receiver1BalanceAfter, "claim didn't skip");
        assertEq(
            IERC20(wldToken).balanceOf(_receivers[1]),
            mockGrant.getAmount(mockGrant.calculateId(block.timestamp)),
            "claim failed"
        );
    }

    function testFuzz_toAddress(bytes32 input) public {
        address expected = address(uint160(uint256(input)));
        assertEq(aggregation.toAddress(input), expected, "toAddress failed");
    }

    function testFuzz_unsafeCalldataAccess(bytes32[] memory array, uint256 index) public {
        vm.assume(array.length != 0);
        index = bound(index, 0, array.length - 1);

        bytes32 expected = array[index];
        assertEq(aggregation.unsafeCalldataAccess(array, index), expected, "unsafeCalldataAccess failed");
    }
}

contract WorldcoinAggregation_ConstructionTest is WorldcoinAggregationHelper {
    function test_construction() public {
        new WorldcoinAggregation({
            axiomV2QueryAddress: axiomV2QueryAddress,
            callbackSourceChainId: uint64(block.chainid),
            querySchema: querySchema,
            vkeyHash: vkeyHash,
            maxNumClaims: maxNumClaims,
            wldToken: wldToken,
            // Identity Manager
            rootValidator: rootValidator,
            grant: address(mockGrant)
        });
    }
}

contract WorldcoinAggregation_RevertTest is WorldcoinAggregationHelper {
    FulfillCallbackArgs args;

    function setUp() public override {
        super.setUp();

        // create a query into Axiom with default parameters
        Query memory q = query(querySchema, "", address(aggregation));

        // send the query to Axiom
        q.send();

        args = q.axiomVm.fulfillCallbackArgs(
            q.querySchema, q.input, q.callbackTarget, q.callbackExtraData, q.feeData, q.caller
        );

        vm.prank(axiomV2QueryAddress);
    }

    function test_RevertWhen_sourceChainIdNotMatching() public {
        vm.expectRevert(WorldcoinAggregation.SourceChainIdNotMatching.selector);
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
        vm.expectRevert(WorldcoinAggregation.InvalidQuerySchema.selector);
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
        bytes32[] memory results = new bytes32[](0);

        vm.expectRevert(WorldcoinAggregation.InvalidNumberOfResults.selector);
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
        args.axiomResults[0] = bytes32(0);

        vm.expectRevert(WorldcoinAggregation.InvalidVkeyHash.selector);
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
        args.axiomResults[1] = 0;

        vm.expectRevert(IGrant.InvalidGrant.selector);
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

    function test_RevertWhen_insufficientBalance() public {
        vm.stopPrank();
        IERC20 _wldToken = IERC20(wldToken);

        vm.startPrank(address(aggregation));
        _wldToken.transfer(address(this), _wldToken.balanceOf(address(aggregation)));
        vm.stopPrank();

        vm.prank(axiomV2QueryAddress);
        vm.expectRevert(WorldcoinAggregation.InsufficientBalance.selector);
        IAxiomV2Client(aggregation).axiomV2Callback({
            sourceChainId: args.sourceChainId,
            caller: args.caller,
            querySchema: args.querySchema,
            queryId: args.queryId,
            extraData: args.callbackExtraData,
            axiomResults: args.axiomResults
        });
    }

    function test_RevertWhen_tooManyClaims() public {
        args.axiomResults[3] = bytes32(maxNumClaims + 1);

        vm.expectRevert(WorldcoinAggregation.TooManyClaims.selector);
        IAxiomV2Client(aggregation).axiomV2Callback({
            sourceChainId: args.sourceChainId,
            caller: args.caller,
            querySchema: args.querySchema,
            queryId: args.queryId,
            extraData: args.callbackExtraData,
            axiomResults: args.axiomResults
        });
    }
}
