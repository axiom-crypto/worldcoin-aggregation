// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { WorldcoinAggregationV1 } from "../../src/WorldcoinAggregationV1.sol";
import { Claim2Verifier } from "../../src/verifiers/Claim2Verifier.sol";
import { WLDGrant } from "./WLDGrant.sol";

import { Test } from "forge-std/Test.sol";

contract WorldcoinAggregationV1Exposed is WorldcoinAggregationV1 {
    constructor(
        bytes32 vkeyHash,
        uint256 maxNumClaims,
        address wldToken,
        address rootValidator,
        address grant,
        address verifierAddress,
        address prover
    ) WorldcoinAggregationV1(vkeyHash, maxNumClaims, wldToken, rootValidator, grant, verifierAddress, prover) { }

    function toAddress(bytes32 input) external pure returns (address) {
        return _toAddress(input);
    }

    function toUint256Array(address[] calldata input) external pure returns (uint256[] memory) {
        return _toUint256Array(input);
    }

    function unsafeCalldataAccess(uint256[] calldata array, uint256 index) external pure returns (bytes32) {
        return _unsafeCalldataAccess(array, index);
    }

    function unsafeCalldataAccess(bytes calldata array, uint256 index) external pure returns (bytes32) {
        return _unsafeCalldataAccess(array, index);
    }
}

contract WorldcoinAggregationV1Helper is Test {
    WorldcoinAggregationV1Exposed aggregation;
    WLDGrant mockGrant;
    address verifier;

    uint256 root;

    bytes32 vkeyHigh = 0x0000000000000000000000000000000046e72119ce99272ddff09e0780b472fd;
    bytes32 vkeyLow = 0x00000000000000000000000000000000c612ca799c245eea223b27e57a5f9cec;
    uint256 numClaims = 2;
    uint256 grantId = 30;
    address[] _receivers = [0xc680592A97E35E981318B49FBeD2f3396Ec7dFf4, 0x66DD3df1620E0b6C3BE13BA50Dac88f97f41e010];
    uint256[] _nullifierHashes = [
        9_152_573_647_681_310_217_632_987_348_218_830_000_142_150_227_431_582_313_786_965_903_541_954_934_978,
        17_961_520_020_524_413_071_862_288_312_249_102_574_632_592_728_502_718_915_127_155_958_458_245_352_790
    ];

    // The address here doesn't matter much for testing purposes. So we
    // just use Sepolia-WETH
    address wldToken = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
    address rootValidator = 0x928a514350A403e2f5e3288C102f6B1CCABeb37C;

    string inputPath = "circuit/data/worldcoin_input.json";

    function setUp() public virtual {
        vm.createSelectFork("provider");
        // Sets block.timestamp to a time that would derive into grantId 30
        vm.warp(1_712_275_644);

        mockGrant = new WLDGrant();
        verifier = address(new Claim2Verifier());
        aggregation = new WorldcoinAggregationV1Exposed({
            vkeyHash: bytes32(0x46e72119ce99272ddff09e0780b472fdc612ca799c245eea223b27e57a5f9cec),
            maxNumClaims: 4,
            wldToken: wldToken,
            // Identity Manager
            rootValidator: rootValidator,
            grant: address(mockGrant),
            verifierAddress: verifier,
            prover: address(0)
        });

        // Fund the grant
        deal(wldToken, address(aggregation), 100e18);

        root = 12_513_188_762_182_928_614_004_040_534_635_102_336_524_438_582_671_349_918_151_801_398_571_764_995_481;

        // function requireValidRoot(uint256 root) internal view {
        //     // The latest root is always valid.
        //     if (root == _latestRoot) {
        //         return;
        //     }
        //
        //    ... snip ...
        // }

        // In this test, we override the latest root to bypass the require
        // _latestRoot is slot 0x012e
        vm.store(rootValidator, 0x000000000000000000000000000000000000000000000000000000000000012e, bytes32(root));
    }

    function _toAddress(bytes32 input) internal pure returns (address out) {
        /// @solidity memory-safe-assembly
        assembly {
            out := input
        }
    }
}
