// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { WorldcoinAggregationV1Helper, WorldcoinAggregationV1Exposed } from "./helpers/WorldcoinAggregationV1Helper.sol";
import { IERC20 } from "../src/interfaces/IERC20.sol";
import { WorldcoinAggregationV1 } from "../src/WorldcoinAggregationV1.sol";
import { IGrant } from "../src/interfaces/IGrant.sol";

import { Vm } from "forge-std/Vm.sol";
import { console } from "forge-std/console.sol";

contract WorldcoinAggregationV1_Test is WorldcoinAggregationV1Helper {
    function test_simpleExample() public {
        vm.recordLogs();
        aggregation.distributeGrants(PROOF);

        // /// An Ethereum log. Returned by `getRecordedLogs`.
        // struct Log {
        //     // The topics of the log, including the signature, if any.
        //     bytes32[] topics;
        //     // The raw data of the log.
        //     bytes data;
        //     // The address of the log's emitter.
        //         address emitter;
        // }
        Vm.Log[] memory logs = vm.getRecordedLogs();

        uint256 numClaims = 0;
        for (uint256 i = 0; i != logs.length; ++i) {
            if (logs[i].topics[0] != keccak256("GrantClaimed(uint256,address)")) continue;

            uint256 grantId = uint256(logs[i].topics[1]);
            address receiver = _toAddress(logs[i].topics[2]);

            assertEq(grantId, 30, "grantId mismatch");
            assertEq(receiver, _receivers[numClaims], "receiver mismatch");
            assertEq(logs[i].emitter, address(aggregation), "emitter mismatch");

            ++numClaims;
        }
    }

    function test_skipClaimedNullifierHashes() public {
        aggregation.distributeGrants(PROOF);

        uint256[] memory balancesBefore = new uint256[](_receivers.length);
        for (uint256 i = 0; i != _receivers.length; ++i) {
            balancesBefore[i] = IERC20(wldToken).balanceOf(_receivers[i]);
        }

        aggregation.distributeGrants(PROOF);

        for (uint256 i = 0; i != _receivers.length; ++i) {
            assertEq(IERC20(wldToken).balanceOf(_receivers[i]), balancesBefore[i], "balance should not increase");
        }
    }

    function testFuzz_toAddress(bytes32 input) public {
        address expected = address(uint160(uint256(input)));
        assertEq(aggregation.toAddress(input), expected, "toAddress failed");
    }

    function testFuzz_unsafeCalldataAccess(bytes calldata array, uint256 index) public {
        vm.assume(array.length != 0);
        index = bound(index, 0, array.length - 1);
        bytes memory expected = new bytes(32);
        for (uint256 i = 0; i < 32; ++i) {
            if (index + i < array.length) expected[i] = array[index + i];
        }

        assertEq(aggregation.unsafeCalldataAccess(array, index), bytes32(expected), "unsafeCalldataAccess failed");
    }
}

contract WorldcoinAggregationV1_ConstructionTest is WorldcoinAggregationV1Helper {
    function test_construction() public {
        vm.expectRevert(WorldcoinAggregationV1.InvalidMaxNumClaims.selector);
        new WorldcoinAggregationV1Exposed({
            vkeyHash: bytes32(0x46e72119ce99272ddff09e0780b472fdc612ca799c245eea223b27e57a5f9cec),
            maxNumClaims: 5,
            wldToken: wldToken,
            // Identity Manager
            rootValidator: rootValidator,
            grant: address(mockGrant),
            verifierAddress: verifier,
            prover: address(0)
        });

        new WorldcoinAggregationV1Exposed({
            vkeyHash: bytes32(0x46e72119ce99272ddff09e0780b472fdc612ca799c245eea223b27e57a5f9cec),
            maxNumClaims: 4,
            wldToken: wldToken,
            // Identity Manager
            rootValidator: rootValidator,
            grant: address(mockGrant),
            verifierAddress: verifier,
            prover: address(0)
        });
    }
}

contract WorldcoinAggregationV1_RevertTest is WorldcoinAggregationV1Helper {
    function test_RevertWhen_proofTooShort() public {
        bytes memory invalidProof = new bytes(1);

        vm.expectRevert(WorldcoinAggregationV1.InvalidProof.selector);
        aggregation.distributeGrants(invalidProof);
    }

    function test_RevertWhen_invalidVkeyHash() public {
        bytes memory invalidProof = PROOF;
        // Setting one byte in vkey hash hi should be enough
        invalidProof[(13 << 5) - 1] = 0x00;

        vm.expectRevert(WorldcoinAggregationV1.InvalidVkeyHash.selector);
        aggregation.distributeGrants(invalidProof);
    }

    function test_RevertWhen_invalidGrantId() public {
        bytes memory invalidProof = PROOF;
        // Setting one byte in grantId should be enough
        invalidProof[(15 << 5) - 1] = 0x00;

        vm.expectRevert(IGrant.InvalidGrant.selector);
        aggregation.distributeGrants(invalidProof);
    }

    function test_RevertWhen_invalidRoot() public {
        bytes memory invalidProof = PROOF;
        // Setting one byte in root should be enough
        invalidProof[(16 << 5) - 1] = 0x00;

        vm.expectRevert();
        aggregation.distributeGrants(invalidProof);
    }

    function test_RevertWhen_insufficientBalance() public {
        vm.stopPrank();
        IERC20 _wldToken = IERC20(wldToken);

        vm.startPrank(address(aggregation));
        _wldToken.transfer(address(this), _wldToken.balanceOf(address(aggregation)));
        vm.stopPrank();

        vm.expectRevert(WorldcoinAggregationV1.InsufficientBalance.selector);
        aggregation.distributeGrants(PROOF);
    }

    function test_RevertWhen_tooManyClaims() public {
        bytes memory invalidProof = PROOF;
        // Set numClaims to 255
        invalidProof[(17 << 5) - 1] = 0xff;

        vm.expectRevert(WorldcoinAggregationV1.TooManyClaims.selector);
        aggregation.distributeGrants(invalidProof);
    }

    function test_RevertWhen_InvalidSnark() public {
        bytes memory invalidProof = PROOF;
        // Zero out the last byte of the proof
        invalidProof[PROOF.length - 1] = 0x00;

        vm.expectRevert(WorldcoinAggregationV1.InvalidProof.selector);
        aggregation.distributeGrants(invalidProof);
    }
}

bytes constant PROOF =
    hex"000000000000000000000000000000000000000000502a39ba7fa40a859c1591000000000000000000000000000000000000000000eae9e14cf0bc1d6e1dd40000000000000000000000000000000000000000000000260d48a718489c1e35ad000000000000000000000000000000000000000000b6ec2520ad20df8a7aa030000000000000000000000000000000000000000000b86157d209e9ba2069f2ed000000000000000000000000000000000000000000002acc976b8f725899073d0000000000000000000000000000000000000000001afab1b9ad1d0a6701aedb00000000000000000000000000000000000000000049515e23f92c1ea404ae55000000000000000000000000000000000000000000000123f24f8ecfdc1f32b80000000000000000000000000000000000000000009b1f644a83dafa770fb5000000000000000000000000000000000000000000009a82634855989fd52a65b100000000000000000000000000000000000000000000255e9f16fdc76f6479360000000000000000000000000000000046e72119ce99272ddff09e0780b472fd00000000000000000000000000000000c612ca799c245eea223b27e57a5f9cec000000000000000000000000000000000000000000000000000000000000001e1baa36bf36c9c7562b9cbe274fa51846f3e0bcd974d3d695ef4905476c4ad5990000000000000000000000000000000000000000000000000000000000000004000000000000000000000000c680592a97e35e981318b49fbed2f3396ec7dff400000000000000000000000066dd3df1620e0b6c3be13ba50dac88f97f41e0100000000000000000000000002c3f330be9322b3f4b8c18f599cc8818a828028b00000000000000000000000034c7d63c890b0024371c0c74a83ba35d5e7c43be143c2c50af9d1f3363e8957ac8c06c87af288bb930d19df1b5c9cae5e22bf8c227b5dc2d5bb5e302d7ac7845678a8cbea28fea18ee5cc7d94c213e6d75ea8d56295fe888cc32ef67186c3724d315fa2a7ec9842d470206d4175740ab33376e7321ff45f23cbdc89fbe9b20492c4a463b9066a3fd9e00138c416526b5d1e4bc6a2ee46bb410014540547302a02f4409ee844c1d4e739408cd4e409ae0db4aa7d70a3d64d59ae22e5fc13749de35e383a0389d3b5251ba02cb449f93dafd50586d2102c42337b5de3f9472e08df474048090c87940eb757a5e843238abeaae55800a8f018ba61010940edfbfbf904c9198c30226a5ccb0a7b156266fc8115297921d34c7c0d9ac86fde337417f7df20fc3d96316d9fd2185cdbee17598c154afa805f914545b878594a87e38fea2c11b31fbf9480efd2825b9f443bb301b134bb3289d0005ca5e62454aab9f7977fbe44722739b78e8ce0be0d76063af6d159a85092a8f2f87b2cf7725de083fdd23f872c419b13869016b25f8d770e128d183781403921c6a475364b9b8b5e9c11ff273a537f530dd26a91fe3498614b5454e78176974062b64f2da84ab1e139f2fd79f7bdae21a73c955f4fc9cf4e179e028280108ce8b9641f7cb97c2fa2430106b21856fc87251c18b2186f4a9c13c48dbd82ebfe29d7ff02f03fde415b7514740606c4503870dffb0575ae9bfa7e4a8b11f07cfb5efe7cb1222160fd3e77a060e1b704f7695aca74afe6c684db6acf9ecbd25aa05ba59cb21af91cae95d111e18f53582055499d6bd34ea98497cfcde5b232e28ff9e55cf9a19fa12852cd9138ea9776773896fffd0c2aa951e9d2971284f11ab705bb5f657627535c8b460ec98573c9967c575b60057566cfb0ef98cd1e31464c9beaf9418aeb64a2381769d765d7380e36a9314bc6ce2021b4d04f8d03602a756e2950c83ccc530d7525f28251f8b7bc7c02daafa58ca5a1dab9ce15dff06d16cbc55ecb99b2bf940c633fa8efffe383d76695a831ae1077eaf909358d3210b40871cba81096d68a9ddbd1df8a3a49977686db96787365de9a250a71514201ece80739841253427f08e10c5cbf812e3375d995fa64e897b3357d8cf408418252d402b0d1c23242d63793b727696420b434851fbcec88027026f0e7d16bd1c17d237126cffec6b8f54e59deb4bdd5a10ca863b9a1e3670d05c8056d8e1e90feb08c687c48bbf82c83ff28231129b08e01566d7cb13b6e5709fa25ddde567097034e990e8e10fc736826e64b52a8934cd2a4ecd1faac9e4efdebef7809e792153fbc2495a2c7844b189f9e35feec7823060ae0cbee4437003bbbf7d584cc10c6a770f3e3081e6f1fe3894c229934fb0fe8f402887b20a283283c1568ee24b0fbceefe20b1bea029d01a702d70a27e830995ae2291b85ad9edb3b0acb5bb4200002696cebfd96a47f57ff493de1c48f476d84330ac8239bbf9ae8d5b691429149cf9375b5cf301de89777f69bd20bfcb3318b9f3f3c4778aa32b01583d443c1ee13eeb1bee0e35e88f82d9c61adb38f8c6bcf448a24e91343440a719994a320ea52e3f6c58cd3000a1735c826e1146c47eab49de4905119a4f3befe8cb995e1753be3f026d9c992742572e603dae0e21e8c5590dea18f08e8d1ef0011dd7ee0ba0dac5a5740577e75e7f4c36a0319295428b9f272c115f919f3099ca291e022eabd3c7151207f72685c2befa91ae60ca93e45e1b7071cb34f6cc39eeef979906903a1e4da42e05b5f6aa31a909663ad47ca72ac93f0b0ac7a5b5b8f61ec60c017705ad579b75f97ea95b9534e263cf34af2a29b98f330e3df7acf4be3b64b90be6468c2130fc84e5094ac55c8a11e5292c77581117ed824a9ced73fadad94a1421cab331588d7aecd14d6d30ffd6ec910ea55db276d77280a86542eca02a631da272a65818192acf87d97146bb0d2a1ac3c7bf28740175264189401155b3d50ed427b7592d5caba4bac1a924ffc29539b125e691eedad97fce970ea9060fb12d54ae6aa517b5a7c6c5425a7f87155576d93f380345a92ea983317d59c7354a0856266c8ca6690a28c63f2daca12a8a787f0e35ca52c84b79b066c2a9057aa3";
