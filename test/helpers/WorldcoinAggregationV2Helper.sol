// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { toString } from "./Utils.sol";
import { WLDGrant } from "./WLDGrant.sol";

import { WorldcoinAggregationV2 } from "../../src/WorldcoinAggregationV2.sol";
import { V2Claim2Verifier } from "../../src/verifiers/v2/V2Claim2Verifier.sol";

import { Test } from "forge-std/Test.sol";

contract WorldcoinAggregationV2Exposed is WorldcoinAggregationV2 {
    constructor(
        bytes32 vkeyHash,
        uint256 logMaxNumClaims,
        address wldToken,
        address rootValidator,
        address grant,
        address verifierAddress,
        address prover
    ) WorldcoinAggregationV2(vkeyHash, logMaxNumClaims, wldToken, rootValidator, grant, verifierAddress, prover) { }

    function efficientHash(bytes32 a, bytes32 b) external pure returns (bytes32 out) {
        return _efficientHash(a, b);
    }

    function unsafeCalldataBytesAccess(bytes calldata array, uint256 index) external pure returns (bytes32 out) {
        return _unsafeCalldataBytesAccess(array, index);
    }

    function unsafeCalldataArrayAccess(bytes32[] calldata array, uint256 index) external pure returns (bytes32 out) {
        return _unsafeCalldataArrayAccess(array, index);
    }

    function unsafeByteAccess(bytes32 value, uint256 index) external pure returns (bytes32 out) {
        return _unsafeByteAccess(value, index);
    }

    function toBool(bytes32 input) external pure returns (bool out) {
        return _toBool(input);
    }
}

contract WorldcoinAggregationV2Helper is Test {
    struct ProofElement {
        bytes32[] sisterNodes;
        bytes32 isLeftBytes;
    }

    WorldcoinAggregationV2Exposed aggregation;

    bytes32 vkeyHash;
    uint256[] grantIds = [30, 30];
    uint256 root;
    uint256 logMaxNumClaims;

    uint256 numClaims;

    address[] _receivers = [0xE90d0b12ca9e3F471864a5bF94A243B547C5E373, 0xF7305a514F832173DbC62c3b680c9ba8aa3b81ED];
    uint256[] nullifierHashes = [
        1_288_207_659_229_337_989_271_359_904_654_696_081_422_749_343_784_298_577_302_435_828_660_062_013_597,
        6_430_922_219_878_999_050_812_897_237_667_815_712_116_826_813_452_450_019_853_970_011_784_686_323_537
    ];
    ProofElement[] receiverProofs;
    WLDGrant mockGrant;
    address verifier;

    bytes32 claimsRoot = 0x5dbffa6bc607b9cee48c54661dde7e317c0d0b213a1aa9383fbf0574c510025b;

    // The address here doesn't matter much for testing purposes. So we
    // just use Sepolia-WETH
    address wldToken = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
    address rootValidator = 0x928a514350A403e2f5e3288C102f6B1CCABeb37C;

    function setUp() public virtual {
        vm.createSelectFork("provider");
        // Sets block.timestamp to a time that would derive into grantId 30
        vm.warp(1_712_275_644);

        receiverProofs.push();
        receiverProofs.push();

        receiverProofs[0].sisterNodes.push(0x95f839bb7a94a62a04d194ea79114d4645c17d164a1adac9b4ce8caf2802c2d3);

        // bool[0] = false
        // All but first (most significant) byte are ignored.
        receiverProofs[0].isLeftBytes = 0x0000000000000000000000000000000000000000000000000000000000000000;

        receiverProofs[1].sisterNodes.push(0xaa1f87d88e3db1bc5cbf310c25bc3622ab0272f2d90624141ede383da7512706);

        // bool[0] = true
        // All but first (most significant) byte are ignored.
        receiverProofs[1].isLeftBytes = 0x0100000000000000000000000000000000000000000000000000000000000000;

        vkeyHash = bytes32(0x46e72119ce99272ddff09e0780b472fdc612ca799c245eea223b27e57a5f9cec);
        logMaxNumClaims = 1;

        mockGrant = new WLDGrant();
        verifier = address(new V2Claim2Verifier());
        aggregation = new WorldcoinAggregationV2Exposed({
            vkeyHash: vkeyHash,
            logMaxNumClaims: logMaxNumClaims,
            wldToken: wldToken,
            // Identity Manager
            rootValidator: rootValidator,
            grant: address(mockGrant),
            verifierAddress: verifier,
            prover: address(0)
        });

        deal(wldToken, address(aggregation), 100e18);

        root = 19_344_841_702_696_546_580_075_889_162_669_344_325_387_178_362_466_204_635_370_382_435_894_637_869_157;

        numClaims = 2;

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

    function _toAddress(bytes32 input) private pure returns (address out) {
        /// @solidity memory-safe-assembly
        assembly {
            out := input
        }
    }
}
