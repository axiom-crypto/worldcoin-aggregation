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
        aggregation.distributeGrants({
            proof: PROOF,
            vkeyHigh: vkeyHigh,
            vkeyLow: vkeyLow,
            numClaims: numClaims,
            grantId: grantId,
            root: root,
            receivers: _receivers,
            _nullifierHashes: _nullifierHashes
        });

        // /// An Ethereum log. Returned by `getRecordedLogs`.
        // struct Log {
        //     // The topics of the log, including the signature, if any.
        //     bytes32[] topics;
        //     // The raw data of the log.
        //     bytes data;
        //     // The address of the log's emitter.
        //     address emitter;
        // }
        Vm.Log[] memory logs = vm.getRecordedLogs();

        uint256 _numClaims = 0;
        for (uint256 i = 0; i != logs.length; ++i) {
            if (logs[i].topics[0] != keccak256("GrantClaimed(uint256,address)")) continue;

            uint256 grantId = uint256(logs[i].topics[1]);
            address receiver = _toAddress(logs[i].topics[2]);

            assertEq(grantId, 30, "grantId mismatch");
            assertEq(receiver, _receivers[_numClaims], "receiver mismatch");
            assertEq(logs[i].emitter, address(aggregation), "emitter mismatch");
            assertEq(aggregation.nullifierHashes(_nullifierHashes[_numClaims]), true, "nullifierHash should be claimed");

            ++_numClaims;
        }

        assertEq(_numClaims, numClaims, "numClaims mismatch");
    }

    function test_skipClaimedNullifierHashes() public {
        aggregation.distributeGrants({
            proof: PROOF,
            vkeyHigh: vkeyHigh,
            vkeyLow: vkeyLow,
            numClaims: numClaims,
            grantId: grantId,
            root: root,
            receivers: _receivers,
            _nullifierHashes: _nullifierHashes
        });

        uint256[] memory balancesBefore = new uint256[](_receivers.length);
        for (uint256 i = 0; i != _receivers.length; ++i) {
            balancesBefore[i] = IERC20(wldToken).balanceOf(_receivers[i]);
        }

        aggregation.distributeGrants({
            proof: PROOF,
            vkeyHigh: vkeyHigh,
            vkeyLow: vkeyLow,
            numClaims: numClaims,
            grantId: grantId,
            root: root,
            receivers: _receivers,
            _nullifierHashes: _nullifierHashes
        });

        for (uint256 i = 0; i != _receivers.length; ++i) {
            assertEq(IERC20(wldToken).balanceOf(_receivers[i]), balancesBefore[i], "balance should not increase");
        }
    }

    function testFuzz_toAddress(bytes32 input) public {
        address expected = address(uint160(uint256(input)));
        assertEq(aggregation.toAddress(input), expected, "toAddress failed");
    }

    function testFuzz_toUint256Array(address[] calldata input) public {
        uint256[] memory expected = new uint256[](input.length);
        for (uint256 i = 0; i != input.length; ++i) {
            expected[i] = uint256(uint160(input[i]));
        }
        assertEq(aggregation.toUint256Array(input), expected, "toUint256Array failed");
    }

    function testFuzz_unsafeCalldataAccess(uint256[] calldata array, uint256 index) public {
        vm.assume(array.length != 0);
        index = bound(index, 0, array.length - 1);
        uint256 expected = array[index];
        assertEq(uint256(aggregation.unsafeCalldataAccess(array, index)), expected, "unsafeCalldataAccess failed");
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
    function test_RevertWhen_receiversAndNullifierHashesLengthMismatch() public {
        uint256[] memory nHashes = new uint256[](1);

        vm.expectRevert(WorldcoinAggregationV1.InvalidProof.selector);
        aggregation.distributeGrants({
            proof: PROOF,
            vkeyHigh: vkeyHigh,
            vkeyLow: vkeyLow,
            numClaims: numClaims,
            grantId: grantId,
            root: root,
            receivers: _receivers,
            _nullifierHashes: nHashes
        });
    }

    function test_RevertWhen_NumClaimsLengthMismatch() public {
        vm.expectRevert(WorldcoinAggregationV1.InvalidProof.selector);
        aggregation.distributeGrants({
            proof: PROOF,
            vkeyHigh: vkeyHigh,
            vkeyLow: vkeyLow,
            numClaims: 0,
            grantId: grantId,
            root: root,
            receivers: _receivers,
            _nullifierHashes: _nullifierHashes
        });
    }

    function test_RevertWhen_proofTooShort() public {
        bytes memory invalidProof = new bytes(1);

        vm.expectRevert(WorldcoinAggregationV1.InvalidProof.selector);
        aggregation.distributeGrants({
            proof: invalidProof,
            vkeyHigh: vkeyHigh,
            vkeyLow: vkeyLow,
            numClaims: numClaims,
            grantId: grantId,
            root: root,
            receivers: _receivers,
            _nullifierHashes: _nullifierHashes
        });
    }

    function test_RevertWhen_invalidVkeyHash() public {
        vm.expectRevert(WorldcoinAggregationV1.InvalidVkeyHash.selector);
        aggregation.distributeGrants({
            proof: PROOF,
            vkeyHigh: 0x00,
            vkeyLow: vkeyLow,
            numClaims: numClaims,
            grantId: grantId,
            root: root,
            receivers: _receivers,
            _nullifierHashes: _nullifierHashes
        });
    }

    function test_RevertWhen_invalidGrantId() public {
        vm.expectRevert(IGrant.InvalidGrant.selector);
        aggregation.distributeGrants({
            proof: PROOF,
            vkeyHigh: vkeyHigh,
            vkeyLow: vkeyLow,
            numClaims: numClaims,
            grantId: 0,
            root: root,
            receivers: _receivers,
            _nullifierHashes: _nullifierHashes
        });
    }

    function test_RevertWhen_invalidRoot() public {
        vm.expectRevert();
        aggregation.distributeGrants({
            proof: PROOF,
            vkeyHigh: vkeyHigh,
            vkeyLow: vkeyLow,
            numClaims: numClaims,
            grantId: grantId,
            root: 0x00,
            receivers: _receivers,
            _nullifierHashes: _nullifierHashes
        });
    }

    function test_RevertWhen_insufficientBalance() public {
        vm.stopPrank();
        IERC20 _wldToken = IERC20(wldToken);

        vm.startPrank(address(aggregation));
        _wldToken.transfer(address(this), _wldToken.balanceOf(address(aggregation)));
        vm.stopPrank();

        vm.expectRevert(WorldcoinAggregationV1.InsufficientBalance.selector);
        aggregation.distributeGrants({
            proof: PROOF,
            vkeyHigh: vkeyHigh,
            vkeyLow: vkeyLow,
            numClaims: numClaims,
            grantId: grantId,
            root: root,
            receivers: _receivers,
            _nullifierHashes: _nullifierHashes
        });
    }

    function test_RevertWhen_tooManyClaims() public {
        address[] memory invalidReceivers = new address[](256);
        uint256[] memory invalidNullifierHashes = new uint256[](256);

        vm.expectRevert(WorldcoinAggregationV1.TooManyClaims.selector);
        aggregation.distributeGrants({
            proof: PROOF,
            vkeyHigh: vkeyHigh,
            vkeyLow: vkeyLow,
            numClaims: 256,
            grantId: grantId,
            root: root,
            receivers: invalidReceivers,
            _nullifierHashes: invalidNullifierHashes
        });
    }

    function test_RevertWhen_OutputHashMismatch() public {
        bytes memory invalidProof = PROOF;
        invalidProof[(13 << 5) - 1] = 0x00;

        vm.expectRevert(WorldcoinAggregationV1.InvalidProof.selector);
        aggregation.distributeGrants({
            proof: invalidProof,
            vkeyHigh: vkeyHigh,
            vkeyLow: vkeyLow,
            numClaims: numClaims,
            grantId: grantId,
            root: root,
            receivers: _receivers,
            _nullifierHashes: _nullifierHashes
        });
    }

    function test_RevertWhen_InvalidSnark() public {
        bytes memory invalidProof = PROOF;
        // Zero out the last byte of the proof
        invalidProof[PROOF.length - 1] = 0x00;

        vm.expectRevert(WorldcoinAggregationV1.InvalidProof.selector);
        aggregation.distributeGrants({
            proof: invalidProof,
            vkeyHigh: vkeyHigh,
            vkeyLow: vkeyLow,
            numClaims: numClaims,
            grantId: grantId,
            root: root,
            receivers: _receivers,
            _nullifierHashes: _nullifierHashes
        });
    }
}

bytes constant PROOF =
    hex"0000000000000000000000000000000000000000009a80edd56c3a787f823ce5000000000000000000000000000000000000000000c243d99712cae439a458fc000000000000000000000000000000000000000000001373ec5a10df92707607000000000000000000000000000000000000000000331abbe63854cf9dbe8af5000000000000000000000000000000000000000000362cdc8fca12d79976c6f30000000000000000000000000000000000000000000011d96a62a4494f7b710c000000000000000000000000000000000000000000378ddbe923dd28390304cc000000000000000000000000000000000000000000158a930d4d5bc2d129749d0000000000000000000000000000000000000000000008f8cef26d6790d9450b000000000000000000000000000000000000000000d07bc1e051d8fbc2b703ad00000000000000000000000000000000000000000071ed964b19833b403ca076000000000000000000000000000000000000000000000c9cf8430cc4dc1cea8a00000000000000000000000000000000c0b86fb0b68ed9139b37b8890dd23e430000000000000000000000000000000027330b69b82caa947fc22501bab8bf3e12f3b5df623983681d93bd6f0f053b8e31c7628100601120fa3ee47383572df3283f5af9d95d9264a8a75abfbb763d87148c80331ae069f8219a759a5bcd4352179212eff9c3bfdabd5ea74aaf3b36d36f64af22ce0ffe131ff77cc6dc3f95ce1b00349c25ff5f410082025f0eda27d0135124b79079b0fd18f8a673f7fa1ffb16488997de441911ca262f7256718b2b06981d581b8fbdf51b0e44857b0e764f190a8808127f2e03a91d3b2de85b5477e14ee10b32ad706ae7f67e1ba8051472075e19f8956b39075e0b2cd146b86e2331ef4f2f2a9f496ab1805ea77953bfe60ba3477a2102d0b80afe32ae9e92b8c06f0c23dfc510913cff16ff408cbd32321b343f9a33dee76d465e9565c521f86cf91601b16036b9bec59cf4b8c96c43d012fab2234db46c71c5ef627165f1f2d97d261abd1767ae23096167b549e832af23a2726163f9904f5fec06db93fd3a16c0a1f3f338c4ce0888e1d3c9e47503110269b0da42cf614bbbc81e3c8add63982ddb0ce9c1dbcde870fad1e19350a58f2403fcc21d16a91fe200ddbd5f05021d55480f9e39b78f60c7be1c4cf8e2b3ce1e66be38b993dd0a9ac0a5e8e5dda92ea238116e989b778908ade65b7ea3a78011d4661d23ab8f44c68bac87d0d40443c29e998718b7c6d622c6a205544e36031f76c386e6208d0413bff8f741c3c7bdc1410210dc08ad8a1dad6bfc5b6aaaaa267e984c7ef4d64dc9bc68f021b2aaf377d7363b504dd8e1ce4b9bc6f74210c52a12b12fd9095a552a7a3ee67163494c277b97ed6c85ed9753437868cb4d4e540e743a1274e5572bb69f52baafc7a3234ea0122110ae028539883f6ad8e082c81612ef940656488d67f2864a778ccf6dfa4488bc9cf6652397900c737066b82b2f034f56f1aa3fe75f43405589d228c710131b2033308e8158e70a0d97e1e23123f77c818d1487fb5e0fa1ffb2cacd77747421429044f340b5a4f17a09fe3365129f034a95e43cbe5188e60de47ab23c815ebaf2900ab3e73fda4872aa2ed72b151635ffdd50df142305d4b412fee29db8eeb165b8f4a5951ea5298977b90d2e209d253c9418392539db11d1b13f421a27b2745b191f86df3600da24b279bd7a28a603e8cb75b136dc00e9c0274ca8e63ddeb90c33acdaa62e2e9eed5872e5cc12122e94b12ec6a59dae332f5a2a1e0fe3b9c993ffd0a066686d59ab96269f33112a821b76797d536dd71d2339ff3c567fdc3b56a2657b370b147d82138ee76b2ffd69e3bd01d2d8889f6bd1489eb5dd71023ab7a84344a433fcc3bd8d5c6893047b48d712f9e827bccdad2664c99852aa5b4d71a5e454546332780d53f8ab7b09c1a31a02a9d5ebb006938de161b7b235052e6ad43dfd138bac3540db3f74171764c4afed01948018ec2deba056dc965d0f2941a3277560ab0b68747bc093562e74c70eca600b29e7c63aed4b31b46a1a373d659dfb3477487b539e65947d86155b95c06d05d04a77296ba9050ecd9f131eb118c12eef8db1c3b85e48cb160c0ce38e7c473734c55b5aaf602d66faf7b39c9c76d1efa14a536977ca869179f7228df5e94dd59bb3cd9c0c72f06ae907ab49d6262e9d43650d5dc856678c1c5f0b1b7c232b850285a6478dcd9b2b26849b0fee586a46cb6c418f1aa86fc1295924897e09f6ef95b8f26dffed2dca233322e7135b39499a0d1bf22cee58542a5327c4e334e707ce72e3f5afff59785d3524642778e0470a1379daba6540ab12f120cd73f2add90b1e804e7b639cc44d53508cb6ac379ab0995cc26cc1b5918db000186232d4d5bd9767c3760f0ecdb83017919dd69c6bc36bb2d7bc10b389194f182b57f216f6ceb5f13b4df0bea77e255e46adc97f44057ef7e6586432906508106ebf6f7fdc094961b2177c461d28a611de5430c3a85121ef8f72f6a6ed46202bff91dcb376a5364c3338f6e681f1353e02fb45f6988eabb76e9a8e824e50312b2b6a6a024f766cbd19555bc169288477a22f14642c6ee33bb4e7074ea169c706da5bc39c79e7d6b07c9939e8620179d41cce697157557321e3f704457fb1452ff47a8efe1d07f28ed20d2f56cfae9e242ef6cda7e298dedcc75b1e78826a8e2d93bf178ce13cbd89e5b6c005dc2763dacb817f07a49eb106702df0d90b95c00d2c8b304dfe576ca6110a995c98e4dec6400d05866dc0ce10d70e8585bd3c8716c17b37075700568fbbced0f728f49e5dc0211f2621b65e60ac4f6041b11c01130177ffce736f3f25d709d397cefeecce8f96351fb7e1615316f78e665cb77510c11256ab08e4f2a50e477ec925cb18176b0531cdf3891f359caa43fb06a78c251d8b9e96bec9134674de0e4ada683943c4294471b27121024e78e256825e4414ca9e75221c06ee4b79304503050b27cc6fbd7051a0b32b2cffc6e3f643c7510dde7503140b07b876130fe9011ea7c20aa31fab51d6b6a7b5d9de5ed067f5ee07875d5442f809ed43ed3088f88b9acd17359dd3138551a1683eeec2df20d4711a3288471b524cb4f387a7d679ac48b8e3cea49cf331e1c04d312da83a17e44d03bed9f4498a750b068f1c57a75aff17599c4855143eccc8d10564a1e4113a38214e0cfeaff573057980eba218c40bafa4a1d7c164c1f6e2762f05af9f4ef0b82f99c91f7c29753b2f72e113f405853344dc8e26077ea35eba8eb0ba016ae2841db151ff1522f0a382202793a5484c078aabbd8f4f9990fe9958fd2761e7c415284e2cb8f80821ef9388011f735681c28bbdb5d8e63f320be576d10eb3e398502cde870a7f6c6521414ecba70bd94a7b36b51d4dce53cfbdd1b0dad5ab3984bb0af40a7031b343c71e03ef48dd2009f07339c260b10b3b9d87ba4230e6e7c61c10da1e0c5f039d380e73249d181d6c37f6ee6948ec2ab285a2057c7d75af6465039cf51592eb4c23a21c8cd43ebc43c05ca976223da653a3ce0d967a461b9832082c3596e3c8b50093ef12136c122040bececc8c6c08732bd73f79c943a77c15215d8054375b7b4b4395e3c6403deff054edd03ee5dc86dd22bcc4fa0cdde34128f0c8a6b684a065f283abb387ea9ddf6cd0e8bfefa99e89038886f42700828d19b09f9c9970be506d788e0b1258e490d4edc038a05eed953afda11fb3a03a5f0585a94ee2ec66d04ab9ad496ed2ad14c0950fca75c78503f11810dca67f202a0d3c7f35a4da467e56e7a0a13cd0371974c3835fd763d74b5b5cb2b9a2dc3ceb257a0112cc19906e9187d9620dbc09d7da8597387b7013b1540d2587c7bc837b0970403b8115294f383bf0159dc8e7e760c951c87f633fcd05992f89b7e92c790651c892a8b3d62711266728eb9750aaa6bf7ddd68681cfe1a1df41eab18d7e72825b7a65cd71d8fa98c19596400cba88f0150ff0af6d4952b8011db8e3739421ace4da64e63b2a2fd32423cd3f2d3d9a99b04b930ae79bd89c90342ea87b90d2d316b1d0ef5aaea9e105ec2b12b735e1192404f5188a196d79cce1b2db2f7450a2a7e2ed4424b6dec33c13501472d83c80ec24fcdcd7806bcff49da43448b5412beda31e4f55977dd3b1364fafbfa862afba26b884fbea3924babc809d8972d0f9f508032ffc98cfd70a856b130548c0f92c6aa43bebf6f5d94e28d98f8f7cb19ca0c1fcca57d2f7db3a0a9eb1a166a7fe64c49714248df5a5f83a02e32fcc32309c0c4a31e9d81ab182f008d938dfbe6fbc2c7983f73008a30a121280fff042a3285b8bb650e3b8284fd00d8bbd94d6802d4ec74e5bd36f43ecbd87cc5b93a304f5667f1826c75be4c94b50c763df1689efd857004bafdf139c7e18515de9d20c08b02eba596f0b2217088b5bf565ac813f3fd37e68afd9ec72e2ade97e662256c349aa3b827ea0c6e0dab6fadef4ee7cb3087284b26e5709524b034438cd225926ef4200fc4e2f9e714829c922c1b7e7fa2906913c91cf3c42e517ab6f47f0535f5674644c33a0b0fc252fce13da482a1a589cee9e40067b17743a430b5772a379bc891a8065efcce1ff8a2fbcb98a880b42ed657c44ed2746145321464e22a8ba45f1c6503a14e774468472cf2cb9f6f4f92f20cda2847dd15de4a101f9504cea5e5999d239536495de108967b338a45861c9c1bae0d1c0756a34c68eb9a2b8f08af00ed1bf004ed86fda5cf7aa6fa6a5995f0ccc8793496c4b60ccef28f20a84efeabfb91baa81f7075ea19d0f8ad8747c55070131a427aa7e33658fc4214ffa1489f561e805f6bf893172ce59c324870a1631e362b87222230555df7510deffa6070ce32328b566c6d87f9bb51da03d59a2d704599f8d0acde639905e8014584eaeddd4c7a315b54c897630b92880ea93d41074c69e670336eb0ee33950d94fdb5633c900dcb0ac51f035aa71907539be4973c8a4a8a82d2a350ecf893305982f6076fe09f8e4a16037bc3a275abffb01f96f6788a50beb4bdbd935d5e2a12ed0d695cf048d2930f1f52947f78381f401a69a8d40a363fff0042d7a3c10fb96762b4beafdcbb40901617063fe8720eac07767cc7bf0c24b316271b7ba120477f846d97f8ed539404bec7c5ae58c02416e7b4e5b407d431c9ff2410e1500a4a886f520e374d00230b8b3f3a96326417e5e885ef32849ab5726f2842054503dded38e216b796696c51f6743f3fc72fabdfecef229163ba327d890e6c07312a65070a9273e82603bd577e5e17325768f107374302bf5f66485f4e6a12541f25ecf3f21622580da375207901ff5633f90b5269b70dfe8f07a6fe74a97da64223a0df9b378ce0e4d5d76f34bc6ef2654a3ce2f051b2599847ede4eb8a1ea02d11102a0affd9934eeb755c287c3059f8dde961c3e8eb1e752c11107a531eabc220cdf6c228732cb80b03f24c559fa23be73ea1a509d835f84416fd0d8fc08bb82271fd21dafe91e274d8bf1df9f483a5e971ab658188d7bccf47deca5999524919cc39a5844027e00c71e625cf015a3fae6c7851030380fd7805148eef9991bf1562effc1f658f7bde6b94b7834e637327b97efd5d0accc429a33e9816f0e84f200e2be324f859dd4901d9cf675d4dd7bb97f994570cb48ac4e2bb38f8ea84e423fa1716eae962288fa4dbea5b9e18a4966c66ef57ee4e92b52958d7bd0324080bd428950cec47c352c450a95b29ddd39085e086a42d5269e1f4c950eb3c7aab123a58a8c053b51087ceba93886295c84fd65d699159c66beb79877e65c731cc0a5a516370636573631af1eade772a71fba7388b2954e1349479364d9b57f4ea166294ca9b055fbe319a5f5d2d2ce5cfecf9db6523e08b04284dccd0f32651741ea5c1b725b4d0224be5ced78ee3b36cfd65f4da26eb0836839014643809231b1ae2014a43f69d8f29ac724b6cb3efe5b9391678e81be691a89f521109e5d1e72df0f24db9e69b4854aa1e4881b65983ce2b903dfdb5fed0ea02b8ebca06bd841b1d91a72c5bf7d7b4322b134ab8c42d866cf90558122d09c0486f9d602e696a2be1f183e0832d0a56ff946f0b3e581cf913a972962b2270d817ab1083e5e49219bdf42b454d879809984d9b97ee79b736d663ca9c0852f8c0b02c84431aeec6180a2c725fd33951c548a7c4feade676bb3273e6691f7410e167bdae770397012e42afce2b5a362ee6592dd89be81de92951f62f31d3dd3737addc4b9887d6f32a462b5584bee2241c82a492bcb871800ead67f72d4176bb522c992abb4eb0892a37b2c7d6e07c9e97dab80b0ae16c728d8607b6da0399e9378b52602f8e87f9054770c38f46f96e4a8916a791cca85c84fcc2997ac7a20b2c8171e6cf4674a10fb47239b07f5b2b66a129a42c820ab523890f8c0d60af8139e9708133d0cd991db90bb37b07e7b46e743e49a1e09cd3c3a90edbf50aeb32e326c210a5eb49890c899a88cbd816a7a6b9365592dd1a60580295acf3c239d28086390764e5f7990de574a499695e0226f6758de2f32288b06a963c9eb89d254db4a8346c3719ed0e09ee026d742d7ab508ce3f36e3cfb6c1ed76bc7730c2df13d1fd78bb9f795d221e2907a2287bd3c9d622f78f8ac137d10078b5ad8df6ac34d59619c812036f10308e450f440b14ea87380a64fd3867b6a5b882f5ae52f3f7291c3b5324f2851e15e54627acad4a699741c307ad28271c023e9b5d82d18f5b04db90cda9b710143dcf579b8df6e07b28193e4f50e713ec19ff9463a88217c1549e2363b2808816b71e15b01e7ab3f4ac7778bf355d4ba52d45d9e5a42fbf1ae933404bada11a272af5edaf6c4e91c618c980b391bca8841b9bce2c15558128ee36fc2d6099dc0d0b4399b74166e685a5e39f0f0bfb318da5546dfafb51bd8d505da3f328fe930ceab81fdcba006ba75817f58badcf471de1a0216c9e7ca151c2123f180d45bf0b28045c8952680154b91b73d5ca6ef7837029a035aeb19b96226a0c208333500c82237dae0ac263ae8215e9d545a64eac15f9fe278f3240d7c20c877c35c2f104b3f5014211c00800cdbb1bcf67894642d8c6bf24aa55154f46ac5227997245208c45d110054570e69948a53aee5af9f89abaf13cd64ee37ac6030c5dfc6f02219aa0a3d3adbce221beae41198955b9cbc64d70f283ce05f6834e98957ed5ee261c69101951caa8df4fde66561535c6bfc47e5794e1484acec84e2d3a4ad9a20de8ba14271d885962c1e8812fe36ff1d9f046c9096ee5debb74f3a3241dc93c13152502caee0d63c5755c2a1a3484601642e97bca39e37b52a22c205a332d8a143582c6e143ecf25c72bf7e1be787fda017e1ae216cd457d0278609bd048ddf1271e479bce1f75cd37729cca89dce4da225a337bceb4d1070860be83b5da0b318e8282284a8ca8689e1f63b636c2da79e3d81aa2007bb7fe75a20748db0b2d715f3a4dd6f379cd27c273ff5e5d81ea2cb2b45225e3ef1bc828da6852307ebdd0316215999d239675dd121f4a11d4efcad994afcb37a8e22532f9f4e6bda872f116e434d3f2a5270d6929795dc865e72fcd89a160fcc206a38544114fd4d2bfd124c0ef2275e5ed01b2a148b582270a663d9a599b73acbc7966ce232fdd7fe250c6f1db288717257953984e1103d6f95b62ad49e2e2a4c429922b8cf08cf79cf05c656b9f3fd9494d1fc5b88c80996370dd7e8511b784b51bce0f998499cdd740dd862ff6d8d2c512aa6841a179d982b601a70bcd2a934eb2f101d35f55d6d6504ec968d7c23040ed0c96c27ba1889501e5f1982081c6383b300b6f32e79f91e1432ba14e5db8aa81c8dbb0c1519e1e3400d7e4f89e9504238652ef529a9c5f22a8cb946367fd059cebd4a870aca2816e98f900f7c56191e416cfd7b00e8e9c814591a6bcfd0b03d744a934a6d3521c378d7bd12644771064b94e29f94e549992315efb6c973274286677080144f40e5bf2ac151c3b44f2f76b66af358ab7a0b07d0b2e784bece50ff7eeb10ba09290749c3dcf81ad477e1689d618b88c84ce12e7df3916b0926ccce89d908be8f459b4c6279a93f9ab2394057e2ff259a3d0c15b78a79956b48bdbbc96ae95da74da21951207ad6c11d062bf0aaa0c0cca3222c38773b6c986c6c4134a6f0ac091c03b7b11896b49f4ec398bfabe1f29c08fa0d1f4185fd189c7d9864b048bbe8c4c113aea98e179c6d53f8f1b0bc2c125a0900493db05792dc5ce2fa3a7de8aa8d4a217987136e0dcfe677f9797caadc63340006e0d37beaccb96c80d73c166b4c9acbb3cc5f2b13d1497830181e8b87a4c42ee4f6593572f0a41d8f2b66a6b61549545dbf5acb93a8955a77f73c6fe88d25085b58eac762d9db81b8ec0c73f84f380484241b0c22155be7ba68db00ed33591621d43b8d411681e2b09e9e3cf2b1aa28f12d7e0c34b5ebd0064fac231c3aff2cf10c11855188b6994f201a4dbef6cdbebda8eb2e3ec6bcf053b0d5a62a4fcc2b6a23d49be35e7b15691ac0dcd70a5be5d03d3007418703db53129473b884480e86af6d56b65b3736e847f71e61bfb09570cacc59fe9c9733f7281f9860176907ba481876e5054822ff445cbe9d3d1ee4ba176749b145224f49e5a3a32315d209987fc859fef11c80f5b617c27f515df3af26e2aa60b43f781004de1b1b61131d11dff93abf2346e63d4bf8cad79a2d0649980d633acce55c087eaa1ca0861325eeb068251da35308c642b82ca93111abde74e510cc5af264a9bdeda071ac3705989a89ddfaa2c1d3c3f607c052a3101d3e732d14ffe282a9f5c80cd1545fef1dc9246d47ae188f39baf0ff7e741ecd8aecc4a244cf39b4dc980d4881618f3a01f33452f18f2302919c802c2814f34c44dc07769552199efc6c4784d7dc064b1d6c093741b8a9b6dc1adca8c3bf8d071c8da3a3f51a3ff538a9156f5a70fe0513b481e1e8a9aab84c70552c7b4277cd825bb54bde668aa616d479b253b7100b104c231b5f0a3fe3bb3b8319d3852e58b9a0ef21e07852fb58774e27c1afdd2202ed885c1c43dfd1e5c43e3fecc18c5d82239793711cfc2b29f3601002ab291921ac6888c1242a6c740014de8f0ab78bdb17ee9682371f16b62a26c02960ae59104682b3feb5be0387f766e109df8f88096d78064821dd9d234117e01c60c23521af9b8a29a045a86543c0fafa0b104e374a4146785db13fef5838a9648fe0c517f83f21e3b7ae29e55189faaffba7a08150c14eb6b47f592a856406b5f3ab8b217124b65f03caed55713ea1fc8ab51e2d1b040518cb3063eea0e12f81f2fdfa0e35ef3ceaf684d3bf6d60e1a3442eedd82cc32c1d7625c9985eb9ede9a484c41dd70a2cfc8fb2805b4c52d859c1f48d28822008d82e1dfaafa1c3ae4428b59f2dae74ce9012a39af6765b685070c69ba5eb09db06c763582ea6f84bbb4b5d1625c699a475b0012076aa71c6715d7f07b980f9f7e877980237b4b853ab1dab811c5f063a0f0bcc91cec18ee49f159a2b626a2505f6d6e6179622cfa7414f8b152f233e7ff6c46618b7275b068f3990ee08161e19a0933261878fc77184d4097f23605f42f5564bb75dfbfce8b8c333a0262b97594d9ba4918721f8467e38a1da18f7ac2718207198c715c1204423df4f3011b3c1358ed22060655c8398ef8be928cb558abf417bfbbe05f3ad0437dc1579e3ff0e49d9906e90c3715b6e73f7df";
