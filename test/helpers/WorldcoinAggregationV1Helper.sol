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

    function unsafeCalldataArrayAccess(uint256[] calldata array, uint256 index) external pure returns (bytes32) {
        return _unsafeCalldataArrayAccess(array, index);
    }

    function unsafeCalldataBytesAccess(bytes calldata array, uint256 index) external pure returns (bytes32) {
        return _unsafeCalldataBytesAccess(array, index);
    }
}

contract WorldcoinAggregationV1Helper is Test {
    WorldcoinAggregationV1Exposed aggregation;
    WLDGrant mockGrant;
    address verifier;

    uint256 root;

    bytes32 vkeyHash = 0x46e72119ce99272ddff09e0780b472fdc612ca799c245eea223b27e57a5f9cec;
    bytes32 vkeyHigh = 0x0000000000000000000000000000000046e72119ce99272ddff09e0780b472fd;
    bytes32 vkeyLow = 0x00000000000000000000000000000000c612ca799c245eea223b27e57a5f9cec;
    uint256 numClaims = 2;
    uint256[] grantIds = [30, 30];
    address[] _receivers = [0xE90d0b12ca9e3F471864a5bF94A243B547C5E373, 0xF7305a514F832173DbC62c3b680c9ba8aa3b81ED];
    uint256[] _nullifierHashes = [
        1_288_207_659_229_337_989_271_359_904_654_696_081_422_749_343_784_298_577_302_435_828_660_062_013_597,
        6_430_922_219_878_999_050_812_897_237_667_815_712_116_826_813_452_450_019_853_970_011_784_686_323_537
    ];

    // The address here doesn't matter much for testing purposes. So we
    // just use Sepolia-WETH
    address wldToken = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
    address rootValidator = 0x928a514350A403e2f5e3288C102f6B1CCABeb37C;

    string inputPath = "axiom_circuit/data/worldcoin_input.json";

    function setUp() public virtual {
        vm.createSelectFork("provider");
        // Sets block.timestamp to a time that would derive into grantId 30
        vm.warp(1_712_275_644);

        mockGrant = new WLDGrant();
        verifier = address(new Claim2Verifier());
        aggregation = new WorldcoinAggregationV1Exposed({
            vkeyHash: vkeyHash,
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

        root = 19_344_841_702_696_546_580_075_889_162_669_344_325_387_178_362_466_204_635_370_382_435_894_637_869_157;

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
