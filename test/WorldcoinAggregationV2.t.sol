// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { WorldcoinAggregationV2Helper } from "./helpers/WorldcoinAggregationV2Helper.sol";

import { IERC20 } from "../src/interfaces/IERC20.sol";
import { WorldcoinAggregationV2 } from "../src/WorldcoinAggregationV2.sol";
import { IGrant } from "../src/interfaces/IGrant.sol";

contract WorldcoinAggregationV2_Test is WorldcoinAggregationV2Helper {
    function test_simpleExample() public {
        aggregation.validateClaimsRoot(PROOF);

        for (uint256 i = 0; i != numClaims; ++i) {
            aggregation.claim(
                grantIds[i],
                root,
                _receivers[i],
                nullifierHashes[i],
                receiverProofs[i].sisterNodes,
                receiverProofs[i].isLeftBytes
            );

            assertEq(
                IERC20(wldToken).balanceOf(_receivers[i]),
                mockGrant.getAmount(mockGrant.calculateId(block.timestamp)),
                "Unexpected balance"
            );
        }
    }

    function testFuzz_efficientHash(bytes32 a, bytes32 b) public view {
        bytes32 result = aggregation.efficientHash(a, b);
        bytes32 expected = keccak256(abi.encodePacked(a, b));
        assertEq(result, expected, "efficientHash mismatch");
    }

    function testFuzz_unsafeCalldataBytesAccess(bytes calldata array, uint256 index) public view {
        vm.assume(array.length != 0);
        index = bound(index, 0, array.length - 1);
        bytes memory expected = new bytes(32);
        for (uint256 i = 0; i < 32; ++i) {
            if (index + i < array.length) expected[i] = array[index + i];
        }

        assertEq(
            aggregation.unsafeCalldataBytesAccess(array, index), bytes32(expected), "unsafeCalldataBytesAccess failed"
        );
    }

    function testFuzz_unsafeCalldataArrayAccess(bytes32[] calldata array, uint256 index) public view {
        vm.assume(array.length != 0);
        index = bound(index, 0, array.length - 1);

        bytes32 result = aggregation.unsafeCalldataArrayAccess(array, index);
        bytes32 expected = array[index];
        assertEq(result, expected, "unsafeCalldataArrayAccess mismatch");
    }

    function testFuzz_unsafeByteAccess(bytes32 value, uint256 index) public view {
        index = bound(index, 0, 31);

        bytes32 result = aggregation.unsafeByteAccess(value, index);
        uint256 expected = uint8(value[index]);
        assertEq(uint256(result), expected, "unsafeByteAccess mismatch");
    }

    function testFuzz_toBool(bytes32 value) public view {
        bool result = aggregation.toBool(value);
        bool expected = value != 0;
        assertEq(result, expected, "toBool mismatch");
    }
}

contract WorldcoinAggregationV2_ConstructionTest is WorldcoinAggregationV2Helper {
    function test_construction() public {
        vm.expectRevert(WorldcoinAggregationV2.InvalidLogMaxNumClaims.selector);
        new WorldcoinAggregationV2({
            vkeyHash: vkeyHash,
            logMaxNumClaims: 100,
            wldToken: wldToken,
            rootValidator: rootValidator,
            grant: address(mockGrant),
            verifierAddress: verifier,
            prover: address(this)
        });

        new WorldcoinAggregationV2({
            vkeyHash: vkeyHash,
            logMaxNumClaims: logMaxNumClaims,
            wldToken: wldToken,
            rootValidator: rootValidator,
            grant: address(mockGrant),
            verifierAddress: verifier,
            prover: address(this)
        });
    }
}

contract WorldcoinAggregationV2_RevertTest is WorldcoinAggregationV2Helper {
    function setUp() public override {
        super.setUp();
    }

    function test_RevertWhen_proofTooShort() public {
        bytes memory invalidProof = new bytes(0);

        vm.expectRevert(WorldcoinAggregationV2.InvalidProof.selector);
        aggregation.validateClaimsRoot(invalidProof);
    }

    function test_RevertWhen_invalidVkeyHash() public {
        bytes memory invalidProof = PROOF;
        invalidProof[aggregation.VKEY_HASH_LO_OFFSET() - 1] = 0x00;

        vm.expectRevert(WorldcoinAggregationV2.InvalidVkeyHash.selector);
        aggregation.validateClaimsRoot(invalidProof);
    }

    function test_RevertWhen_invalidRoot() public {
        bytes memory invalidProof = PROOF;
        // Changing the first byte is enough
        invalidProof[aggregation.ROOT_OFFSET()] = 0x00;

        vm.expectRevert();
        aggregation.validateClaimsRoot(invalidProof);
    }

    function test_RevertWhen_tooManyClaims() public {
        bytes memory invalidProof = PROOF;
        // Setting MSB to 0xff is enough
        invalidProof[aggregation.NUM_CLAIMS_OFFSET()] = 0xff;

        vm.expectRevert(WorldcoinAggregationV2.InvalidNumberOfClaims.selector);
        aggregation.validateClaimsRoot(invalidProof);
    }

    function test_RevertWhen_invalidSnark() public {
        bytes memory invalidProof = PROOF;
        invalidProof[invalidProof.length - 1] = 0x00;

        vm.expectRevert(WorldcoinAggregationV2.InvalidProof.selector);
        aggregation.validateClaimsRoot(invalidProof);
    }

    function test_RevertWhen_invalidReceiverClaiming() public {
        aggregation.validateClaimsRoot(PROOF);

        vm.expectRevert(WorldcoinAggregationV2.InvalidReceiver.selector);
        aggregation.claim(
            grantIds[0],
            root,
            address(0),
            nullifierHashes[0],
            receiverProofs[0].sisterNodes,
            receiverProofs[0].isLeftBytes
        );
    }

    function test_RevertWhen_doubleClaiming() public {
        aggregation.validateClaimsRoot(PROOF);

        aggregation.claim(
            grantIds[0],
            root,
            _receivers[0],
            nullifierHashes[0],
            receiverProofs[0].sisterNodes,
            receiverProofs[0].isLeftBytes
        );

        vm.expectRevert(WorldcoinAggregationV2.NullifierHashAlreadyUsed.selector);
        aggregation.claim(
            grantIds[0],
            root,
            _receivers[0],
            nullifierHashes[0],
            receiverProofs[0].sisterNodes,
            receiverProofs[0].isLeftBytes
        );
    }

    function test_RevertWhen_claimingWithInvalidGrantId() public {
        aggregation.validateClaimsRoot(PROOF);

        vm.expectRevert(IGrant.InvalidGrant.selector);
        aggregation.claim(
            type(uint256).max,
            root,
            _receivers[0],
            nullifierHashes[0],
            receiverProofs[0].sisterNodes,
            receiverProofs[0].isLeftBytes
        );
    }

    function test_RevertWhen_invalidMerkleProofLength() public {
        aggregation.validateClaimsRoot(PROOF);

        vm.expectRevert(WorldcoinAggregationV2.InvalidMerkleProofLength.selector);
        aggregation.claim(
            grantIds[0], root, _receivers[0], nullifierHashes[0], new bytes32[](0), receiverProofs[0].isLeftBytes
        );
    }

    function test_RevertWhen_invalidMerkleProof() public {
        aggregation.validateClaimsRoot(PROOF);

        vm.expectRevert(WorldcoinAggregationV2.InvalidMerkleProof.selector);
        aggregation.claim(
            grantIds[0],
            root,
            _receivers[0],
            nullifierHashes[0],
            receiverProofs[1].sisterNodes,
            receiverProofs[0].isLeftBytes
        );
    }
}

bytes constant PROOF =
    hex"000000000000000000000000000000000000000000b6a90d93715b402e484a6300000000000000000000000000000000000000000027c5cd0f0911ed5235170f0000000000000000000000000000000000000000000020534c5ebcd3c8fb67b900000000000000000000000000000000000000000026e28360fc5762c4c0a59f000000000000000000000000000000000000000000b5dcfc2b07399d703329d1000000000000000000000000000000000000000000000d3136886a96e3640bbe000000000000000000000000000000000000000000fdad6c607018565a47d3ab0000000000000000000000000000000000000000003845c40fd2e77ee07b613500000000000000000000000000000000000000000000263a196ae4c9a7431e59000000000000000000000000000000000000000000798222a2f76c32417593f80000000000000000000000000000000000000000009e6b57c2f9e926faf8b4ce0000000000000000000000000000000000000000000015367e40f52ba62f83e00000000000000000000000000000000046e72119ce99272ddff09e0780b472fd00000000000000000000000000000000c612ca799c245eea223b27e57a5f9cec2ac4cada46f45325a9f57170b5daeed292ccc1519963a733514004ffc2a7b8650000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000005dbffa6bc607b9cee48c54661dde7e31000000000000000000000000000000007c0d0b213a1aa9383fbf0574c510025b1740701ca29e9e9c4690473f6e3ab447b3fca6042464c30e43ac9bd5137ae5733002ff0acf8eefe0c234c8d44963e772d53fe30c6f98fd5cd11331d11811471c23cbe25cb7979e156ece6469b4f8da2bf89dfc02e08dec6b051966756d4414931135148b4210b4b8b6282dee8474b81861a3b15cf7ce93089fb9b529ff84a3ad0ed2f3cbc4dddf0135d78357795ddd2255eee3dc5db0920624fa42048df6039b08abcdeefddb4e17f00484dc736526e77f6ae37eaec11eef2f7ef7ad1b2417622839f8d8d09902cfbb07814ce7ea245e771dfe018955af6acf361af1f1360feb20ddadfef86ecbf77fc5faec0b2e1fe01c1f44a193228755dae4b37af01653f11a803e2eeb7ab93d596f1a769d04eb4885d9c65bc737cfcaaf9dbca3bedf26a0211a74f7b9e8ba132f88e008bfcf235e87a97a3b0251e03994ff5ad94b29425e26d24ccee0269f28dfc422a768391f768615f483d8970111378fcbbdc9a681e7083672e8e6d88c1c5ea025f22b7ebcb6c65d89439495689c953000f031fb82131b8ecacee931e240a7502164f7560a75319eda49e18fe9882803bc73d374a952143444aed7f30b733f5479cc6007813fb1b8f159380cf88cbef1eb9500c4b65f008cf13224e88a35f0bc88a92b7be3b356a28d3a8a0ad7f4b885455c999f88c50c7c9f9576cecc3ce978678b54b7711582bb61f338edf0cf0ed328e09e068ace14dc3ec7c5392365e106be641cb798bf2e80b27333a1f3fabd379d2d03c52587246d2d9d409e1e2a63a8af6870cfd87e9f29f5f33741c5a267df9f27ff3350ae0c3058af4342545d73e940f328a7721ae1af46d4570d440563322a090b3df907175ad13459c0a8692b0b3e17ebe591242f22d52019a21fdb6d088863c24177692a4f7707ac44ff0119423e714c95e722b73421529b153f80956a5b9f5c489dae1bf142c04dde88336d9df5978bdd5bdeba31063c6eb247f469a14554a24fa8840656a593326c9e8b43a32fcfc1b7856007edd79d4e5688e17edf8ef47bcff5020bab5e44e6d5f996f84b9ba63629108230716826daa8e30f96423b4fe053a01d045b251ef66e4d9889d73cab5b07c7dfc87c308ca952d4cfc867b216401babf720a9cd8e6d71522eb038384e8dc2f74065c5700d0215f4f87ce222848c8adcec17f84f61f7170b4529736e2afc2d04768f282c43ca7b5decb5835be0169804dd115f947afa23deda54c5fdee8299f7e1ad1bef9db14b1f186d05dfe41364492e2993948405d0953729288e867a37b0e3fdaf38c059827200f8418a4653ff63ab2d566b84aa65c0747d0e56162de9cdff9c59e5c528533568951e6aeb1fcd5e9f244a6bdac2398c9690843b6948518c847e3b40a6b33bd0448663ba556345011901f245d4199bdddc6a5b7df6034290e6436b80bcc69d8b3168f05ad4b3a2438f178bf396b9634c7d32a74ffd08e4b509f7076ad9f0e99702c6f73bdf1f9e4af62134b73e7b284d1a5d09744aa915146a81b4cec9cb1849196271c5c039c7ead6012635fee4494f839f4f2291f121046c533b69bc23b6d0e98e7acec9e9c0a05c1c58ac871e5e7da97dbca82f770ad12601e859851322ebd15fe291ccd783aaf805955952678baae23a3c90b25278f64f5dbc96e4fcb7126cc0b61c416560435f2a3d7003deccd3e2d3112eacad3dd5f56e8af85e851de5299ac9227a733421bf03b0906fbd51e66ffbb3902e011c05319823ddc4e7f86fa0dd44b95bb90567e50991a19cbd1b6d3725045908c1f15c85c0807373b89e47260723060fa8cfe8bf258da54d28b893cd3bbcf819296b424b357af3dfba411b739f054ae0cfc72b3324f5bff6999b145b3a946efc0552e6c01955403e298a2ad049421f887161a9100db49afcdab1b6130a7df71665f68068e91c663cc3d74a8bec2c37afb25018a81a35056738147defbfe8869e6ce7fcb1bafcdad0886466dcd076da52ab1c8540218a6017bd31125067c103895964354ad1ae3e87b52f932ae8e86800dea27e2a01fb4dfbdf7aeee53ec0b07f85bae942bcbe95a3c3a81a2417b3b40c1b52658e15d97f88fa09724b6414348edec1ef8ebf4f1a28eb5a7ecd98f1a0abd6ff2e9906c2eb31ce7571a3f4b3ba6a282b0a794766006ccaf67fe7f81a2997c5bdce710749e8719270317b3c80b1a52a7e5ee0d3f745174ad01c882e1ddcbd8d0d5d7a0b136ce025c65e1aa67e7626ff669edd3b7efa6e45b61e6fba42c7f7c83792bc07191506ece247802a154114575afe346a81985abeaefaa2fa121aac1a687f483033d5724d7afbd66d99ca6d2b3e4d241cc23127d86cc2164a1fd9fff28c6a531712e6b324dd2d56a9f0795ff795694a2ceaf609490ed2b7bf93ccca0bc8e0cf2d633628475015a7b1f51851f757986e4ad2070f1980ffc0ac5fc31909a2906c11827bb7bc9feaf1ac4ee9769b986c4203479c5020a7be9042767c3031f1621a2b30f81ababffd2d57946a225b05c15c4d0e7881c3d8d42a7edd5104d5307a8c213bf4be88ec8c75586b34f2a8728f7d39be433d8be64f8b6201ffb9106f8cfa147b345e55093b41243227ab32199550cc8240825c156d67550597b4f9de15c21d9a08bb02b6be1138a99d20cc0af6c6bb12ac1becf7852e0feff8b8254f75db23160844f6d9627a50c50eed15c3a8d7a46d9652fed3c7e64bfbbdc245d1a621094a1f5a1868de4f513bd8f523ae690bd08c0c3cc6167d32ee46d3101689838d100f6d78ba076f0846d0e6cdf9341fcea99e12e24564aeced6e26ce925baef9a24ea7f8aa18ae3fdaa6e5f420f88b72f9ef00fd4deb265fc168d6f5438db170f08ac05769351fb01320897741795b0392e290c0ec19b2628ae5c1b7d2efa4d4b26ca3116f7c88747bff87e63d316005b86768720bac9afdf9e24628b54a127820664ba4fc097efa0df38a0f71fbb5c501f4daae916195f1b832950546b4d94522dfb74d2ba9c742880d95ae4575964444c3211d75b3a03ba133ace88c66bbec120510c954df47d9c967a788591da906d203f89a2f72077226c72a50d97336e812754d9df1cdd4b4c2984d2d8fdf26a6a637190aecbaf408f01ad1dff82536aec01df3ca7c57e3ec42929cc4a7906bba55d97b7f7dedf3e0e89b8dcaa006c93153052effe1c43bfb60492d0502e9008cfc031c8f23e7b8338967a3e922ded58a211a8fb9bdec34a42c6ff3c8e98743903e65cead723880c31664f6995e684491e1a8c85f68d163b4dcfc258138d103dc1403d936e5c420a2412670b6413b7f1d51468b4ea8b807bc2212c2580d89bc8741b0c436bedaa7a64965cb013e1d7d0b822524c4fb2d334206fb5d13ab1f4a5fe7c17775cd01bd657bd661a53490aebf21bd0883dd98068750e983fdf0fb4aa0ab2b6eba78cce6822fa5e3c9718dba39501fae77c1290f9bf047b0f15c0880da97eb2dbdc7b1cc762d20841556c38b1610eeaed5d0473a5618345addfb413485b41bb9d6355a5a08cf7ad408aae92668b079994132f26acf970630ebadee558073780ba772168ede027661ddbb4581bff0bd9dc3dfa028585534eeb6961471cfa994eda5cde833907d96a37f853eb9d3c06e02d7419e9abfa7be1502191e9b1ca10a7a80bab75b035508f073bd6151f651a7165d1f250f708bc153dad216b847de849cdbb5880fa1f831c9d36e430e39c2641af89c163605a10fbf21018d47232a89e0658bc842a1e04783a4aafee2f0718cd5b475507dd2a92a19948d27e839c7ab919ff4e72d28a3fe3d6012ac79de42f76418ccc2679ee3ffcef43506c2bb86619b36e0781ac771d86fbca4e35881126d9d8a90e734bb1d38bb340f2fa075b0ba95975d727c8b3732980b25e6e35b10986d61298ed0c78773aef6030c5cd1e7223e8adc302be186250144ab8a26c430931f999978cb694c57dba3aa5bb9c4c9fc80f5e76d048db2a2bf2a4370998891214bf820cb4c2a0831ced1ecce4b6b5cba65bfda1a493379eb6387bbf9c8bfd1d0dfddbc3de9db5cfc7918e127f1ed3cf1a36cf4d135cca1e89d3f2d192720b0e2d3c700ec58f21db3d063b527e1166d60181c760c3e27835eebe18e4f913251b73277156e8798938195d3404ab431e8f9b741d9103b07179561980560c30fb254b5fbd3548a9d13124f62fcd92f3fcf8bb981326427ab5456cc68ae33a1c732f3e4b6d3774dcb6d990363d8f8d3d42fdf3b6e8f13b69ca989666cb266df84c28891120b9551365e0d1c18922e315627959e42ce28f63f12b555bd4cd9c68fc18e7fd60cf47b94e7201ba2078a278bbd90ad75de1c092cacbb95a062b65c6e814aeae6f05c05a3cf767e4db359fe9ff88861bd6dbc257b00e7f27b2b652095722184325ff1b70683da1c7e14081a743a22d1a709ba91ab0fa74b492fc8cf3da07bb05af2f375e14c3819fd44e54fa28b2d9d5924c9ae315b0cb49dd7e430c24141aaeff73c3cbde4cb99f77f61bb1fd48a818c44263bc86b8e2210ed49448c701fd66faf8dc8cf2f8853f2f1be9a13230a404d65ddede76c2c5e39842ac49b31f04f861cc82947950cfb7c6875b9710661f2cc9cd032d277333e7aa3e15563e28527f6d10e8c0c2543bf7d0dc6ff3fd3c48c41be98ad1371f45ae13c397fb6a16d82eb488fe120c1d1a75ab6976fec968719fb03bde41e2ecc12bed9e4031690ede55d2953bfdf099c8dbd3d7e7cec511380b8a99498ddd84751f23b16ec1a6049392b815b4f65f15117eafbd4a19ca2ae78a8b478521eda852908b783d9d5922e7a9b8856b7c81931178a48381cd0001e36f2d81ae0fc047cd0d2faf298df301f49cd353250bb4fa16acd2477e74c1b62a2c8bebf7b93b708395d6d6ce1c490d37bb2b0af5124ade8399a0f0f53adf2110d4fea1cb900635f62325eff7779e1b46bbcd8f0341c3e7a9155b30ff9854b7e208c4f26d5565bf789621e315f3741e6af8681ef0d3f0c0378f426618c5aada99e97eeb9cdafa03c8233be08219f72225bb92c3c93c40e4b07119739db9fc3ee4ec6dfdb8ba7f78be32fa646a90810618c2be763e0d6fd76f55015b14d76403590e11ac9518d9cf1ae4df74c399f421134f043d2e3a2560563061cf61d12ae683188d3d39e21f308dd92e56e70dea1ddfe8f3c4837abd759da96dee1f9e664d6fddcdfd41423483d0e7ef6da4333a208cc0584427468e4aaed9f6cbbe2e4c9a2ffa380c9a078bb8b3f3b725544596032d5e97ba438fcd214074fc64e643676f55eee1fe8817094f30d82072ff69e21f1e7d6ab5db19cfaabd632fff1bb08ebeebbeb071e9cfa3ea8b941ac5981489252c432c24e049d8ea8e5866dda69b2bef59f56ea83194e553ca0d9ab61ed0631598cf76578cf9fa43a13b32ddf98c7692101b0e90bceeba126a7504da06082c2e326248ce5a0614f9f5404e28e5b239fc9e4bfb02e853feba7c0f50f1a8ea290b3df9938dd8c1e4bcb90273c609400a4a7cb3f45221d8f22096ef12e87aa8931ba4fbf40379a2aa6cece90c74538266d133c3b8ccc88cdb9984f6c2fc36c18829b436a56b46cba00fc92ca43d45fed3a2df458ab3a25baee7522d81901f05d223a3f0169f1c75453bd0e3b5b171d625848c3636880f917056abf7d5f2a6c93a236c4bc5dcd3653fde188c42dbb3a48bc980df783b61589bfb377097b8b788e91a8fe36b48af84a68d61f4bac9c46ca8009e5977a3b6f16e73d005e40c54f9ac1120a4aa3843471bcfdc72f969f49aa4afb056b50d86c0aee01cdc89c8d5a5e62bce137c824887c422d754c3b44589a1ea05bdd7133cd8790cabd1604973d84f140367dfe0753fa505a69ff824db6d7a455ae962bdab7d5a18e88d97615bf91c146e7ead0d3cc27e227a133c6a6528eb5c45c504fe0a000f70fd4644d08a9c282b64b7a3261d515624a524acf0e52308f845c6864d62258620a195185dcbc06b08ea7f0fe9229d016744c62a072554e68e4eb62d074949bc419e077b96cdec291a970f845dc1f1460d8ae5ab4c7328ce9c973a18a796628839e6c369ab7dfd1b1fdb228c1e6f00216a0d4d042440a84a92ba8412d68c5eca6299ea85f5cba1842875af2f4bdbf6b3fdf0c7f7685c14ce9ec40505a63c2ac12940794e809a4e792c3affc3d720c495c375d5aacb9a2d17d3110f5984c75302ee6088c02256b23f00c3f85fcddd1b98fdbd9aedafcc7f44fb51b3001d15dcbfe952a225797959271e2d2e341895fede8cf1656aaa7db68c39b7bf64d5245840f30db7ee8615704027dd8ed57fc08a9d6018a10f471e011b3a54718e4477c6ee756c1794c8fec7691b105148cfceb612489cb26c85c0ae1ae5e8e97f0d67995c7e117796788436d006e329fac47f4f3e7f435899140806a04df144a0918fe56e2e47290380e6d2f9019288b7a9e0adb855ca618247ec9a07376250989cd13382f86532ee175409cb2d6b9fdc6f088b876a74f2becbd2ea504f83926bc7e0afd156dc9f482eed81981c64cdcc4027d04a1e985d343c9484806415d79e37ea781d326a74f5d2cec11507b69c49bc817cd00f4a198f178a4a8b70926098fbc346fd302dcc61de7658f216d9983c390ac846c17c99325b37839762bb26f65fe8e157c395ec99a3da08f319a4644b9a1e4c9d60364d3442995260940ed2abdaef724394c7c06dc14dd25d09977c05ca16a3e0ee6f6b9dfdd1a1440e781b6a14ec72d14775c024388e228400a83d43199ad2cc8a2f9b008bf7aaa3249b0434a19cd554651d3b3c331bcf3f1a184471f502ab623b3380fa6fe2fb7bc9b83131cf2d9a5ca539aba81d9f96551df218fe26d8046de6709dd919eaa2f677747850b28b999471a838633e7a8b131010f02f0f6b20b86083f1de3c9d5c73239905f9fc78872fc7248943bae3f37612dc34d207a2c0200a72ce021445595f7d3a6aca1896c8041e5a023dddaa84a427f76a7573618c64ec1eff73c5ed8884fab1f8348aba51b0d40f1e23b78a530900ca5a83680941dce8bbf8417eb0ccd259fe72de0d59151144849646980ea28b1f86264da3a6b57ba1607950e6ab2a0654bc31ddff6b3eb02b4094e5c57aa3ab0ba28cae2745d0dfaee04fe582a83d8e7f49f0000ccccf9b5d7c0bb2a29e47af038343f9740fcd782125160f3c7de72d0dff813b19cd713aad27d41a7e16c5cc0775e4339904a8e0c38061e71540898d2dfbf64c00f93d9a1ac5474aac295eeb0e8f7cb7d72f126d9fa39de064497a4cf83e2b53b724ef6794264ea5e380234e2035da5f48a71eebfec38d9728d6c5812e5eda57c9bb8a3e198706debea7e50026a6a4cff268f8c0dd30f7872fcad58d275c6aa03b4e3d3e4cb63da884b30aae001f775f0aecb459f60304904ca0dadbf11baa3959da3989523d57630092da492e36efd883cec9af9876059ffb5c0693f81d8de2df0a7d18ab8dea1a34bff6b22bc6882f6926d6743b8168eb15c5def197615342a2bd439cfaf30e5bee1e370e02ee7c4385e600708d04c00f4da56ea4de6e188aee7b9ca2fbb1bc6b1ec9535d10112ab06e89b702fd1fa146469691bce31e96e720942bc083e9260e7763858302f27dcb60a255a792d4e1d0fd67c25a7a1a3e00ef0a71ece80e94db94b924ea1e91c8b983c52b35d49a9c049c116f709d75c3de1d7279f907e6387289bbba4c29aaee623557e04e17c46a6e66c711a886a86989535d6341021ca4d8610ddb4804f1a4cb1aaa398d397eeec58b652f5461fd91059d63fd374b72c6f82f82d13824b83b5dd2f90341970e65f208454edeb4c34ea00a1884fae29869fb5090bdc92804e27e4825484e32666e3ff79c526f20b1b208dc4fe71f291d3ae92058f6df03776aa9aa6e0b422e1095fa4432f90b0da26541d54585d383ffddcfef127d091d80af29249530ff5d716724c28e3a5566cf1742f7cc5e4106ef9102d7cb78791aa4da509a7204894a7dee9c4207ac0c7d63d7f10f222ed976ef7cb2e787dcaa2cfd26d705a0ed5a9529ab1b8c19cd9d19822be94ab9f3af565191fa267f63782f97c2b39d8876f78cecd075c556ba8ec2b6cc5cbde02d0d8d123b4ab5cee6b11fa88ce4d41ea64e1d2c30c6d063c4da2370942fe985784913b23f00d426754a0c49f3e1429d1e86c2175fe7527ce345381d57b1b99a85b37e1a03a1002267550bd803f1cec594805dd9fa57bfda854871a3d471be6044c528983fb0d99b5a182bc39b776338bd506d1a865da437b4994dcc8226ebdc637211b7d22aa6b9e47d236b9fa37bc2ae70c45faa46e0907e764976d55e15250ceb6283ae09571c4f382e1106ef025ff02a21df754a4b78541eb45d30aadbd8caac24bc2c1328ce84e123aba578872684ae479863e5ae70105d679b57277609709d9cef35f6c4d434b40cd918c61d951e356c4a7115dfe2d37f66a79630c79369f713da5409d9f6798726f5a32ebdc34c462bb77681532c108f8e0ef051374e9659f3d6c19c3f5a908c2c352233ee0a7a92fb9f587f3c39c33ae76cc70ba66d3e44376cfa451dd7d0ba1a50f26c0cee3a4b2dbd467e0b26307bebb20cced52de53c089438944f2663f220f1245c2756271136e4d65bb5c542c2541328dfff1a991b11a8da1f9cf56da928ee2dd7f23fed072255ad75ec2285e736fb8ca0082eefa96280ef7ae78c5fd11738c263f6273bd76619a61e29a062497055883d390cbd1545228c3c318dea76021bc920f5a96bf128faca9d5a762c6d1df87d50263605a21f8b857f1b39407906b12a04d7ed5dacd0de7d8359ae63f379f25de1f137dc7e5966fb418dd90ad122efe6c1501fe169ae6e0ca1f9e39bbb96b833d076b96903d7863fa3937b91ad2d2ce2aab8afe9b1c836ca2e12d8d969e1954db96ef2f886830749dcc825f03d0b608a2ba81972d0029570b4b0b9786cd658be60836e0b6a48dad12fe28557c72f5ea0f4956c02d1a4086139a9911c84c48f9ff262292b5a1dd8ba6742e2a02920c1bfd861b77551852c07eb969a009777e1d5d744672ec67f67de2680d59aac13488286dccf47f97c817d7b4d0289467e0dfa250a08e1637c36bfe8d545db6c006e802fb05730f3b1bdbdd9c1ce552239bafc910546ab409b3059800bb564bb1cde878618d959b2d3e32fc07a7c40f092d159c0a6662e76ca4f672765592a87";
