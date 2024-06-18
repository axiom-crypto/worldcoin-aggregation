// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { AxiomTest } from "@axiom-crypto/axiom-std/AxiomTest.sol";

import { toString } from "./Utils.sol";
import { WorldcoinAggregationV2 } from "../../src/WorldcoinAggregationV2.sol";
import { WLDGrant } from "./WLDGrant.sol";

import { stdJson as StdJson } from "forge-std/Test.sol";

contract WorldcoinAggregationV2Exposed is WorldcoinAggregationV2 {
    constructor(
        address axiomV2QueryAddress,
        uint64 callbackSourceChainId,
        bytes32 querySchema,
        bytes32 vkeyHash,
        uint256 logMaxNumClaims,
        address wldToken,
        address rootValidator,
        address grant
    )
        WorldcoinAggregationV2(
            axiomV2QueryAddress,
            callbackSourceChainId,
            querySchema,
            vkeyHash,
            logMaxNumClaims,
            wldToken,
            rootValidator,
            grant
        )
    { }

    function efficientPackedHash(address a, bytes32 b) external pure returns (bytes32 out) {
        return _efficientPackedHash(a, b);
    }

    function efficientHash(bytes32 a, bytes32 b) external pure returns (bytes32 out) {
        return _efficientHash(a, b);
    }

    function unsafeBytes32Access(bytes32[] calldata array, uint256 index) external pure returns (bytes32 out) {
        return _unsafeBytes32Access(array, index);
    }

    function unsafeByteAccess(bytes32 value, uint256 index) external pure returns (bytes32 out) {
        return _unsafeByteAccess(value, index);
    }

    function toBool(bytes32 input) external pure returns (bool out) {
        return _toBool(input);
    }
}

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
contract WorldcoinAggregationV2Helper is AxiomTest {
    struct ProofElement {
        bytes32[] leaves;
        bytes32 isLeftBytes;
    }

    using StdJson for string;

    WorldcoinAggregationV2Exposed aggregation;
    bytes32 querySchema;

    bytes32 vkeyHash;
    uint256 grantId;
    uint256 root;
    uint256 logMaxNumClaims;

    uint256 numClaims;

    address[] receivers;
    bytes32[] nullifierHashes;
    ProofElement[] receiverProofs;
    WLDGrant mockGrant;

    bytes32 claimsRoot = 0x015796a37659e8fd40c2056568853b57d0ce874dd54385dbc1e0c65256fe8058;

    // The address here doesn't matter much for testing purposes. So we
    // just use Sepolia-WETH
    address wldToken = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
    address rootValidator = 0x928a514350A403e2f5e3288C102f6B1CCABeb37C;

    string inputPath = "client-circuit/data/worldcoin_input.json";

    function setUp() public virtual {
        _createSelectForkAndSetupAxiom("provider");
        // Sets block.timestamp to a time that would derive into grantId 30
        vm.warp(1_712_275_644);

        receiverProofs.push();
        receiverProofs.push();

        receiverProofs[0].leaves.push(0x55d05ad66b187a7533750526f6386d98ff0859d326ea4f1a2c846def63390990);
        receiverProofs[0].leaves.push(0x4b4efd86a2cec7174648fca755d3b9caf672051f139e1b37846d357f29e0d889);
        receiverProofs[0].leaves.push(0x2a3c055e5aad1f95e094e401d23a52dd4975291cc3ecbaef3a11c98dfdef94b8);
        receiverProofs[0].leaves.push(0xebfb29350462bf97adfa61b387536ca750b8f5fc13c9221123f5ca41df8b92d1);

        // bool[0] = false, bool[1] = false, bool[2] = false, bool[3] = false.
        // All but first (most significant) 4 bytes are ignored.
        receiverProofs[0].isLeftBytes = 0x0000000000000000000000000000000000000000000000000000000000000000;

        receiverProofs[1].leaves.push(0x7dced535b129e25d38e569ab2c69ee538fb27783c37857fa7f2c3703fb0bf9d4);
        receiverProofs[1].leaves.push(0x4b4efd86a2cec7174648fca755d3b9caf672051f139e1b37846d357f29e0d889);
        receiverProofs[1].leaves.push(0x2a3c055e5aad1f95e094e401d23a52dd4975291cc3ecbaef3a11c98dfdef94b8);
        receiverProofs[1].leaves.push(0xebfb29350462bf97adfa61b387536ca750b8f5fc13c9221123f5ca41df8b92d1);

        // bool[0] = true, bool[1] = false, bool[2] = false, bool[3] = false.
        // All but first (most significant) 4 bytes are ignored.
        receiverProofs[1].isLeftBytes = 0x0100000000000000000000000000000000000000000000000000000000000000;

        querySchema =
            axiomVm.readRustCircuit("client-circuit/Cargo.toml", inputPath, "client-circuit/data", "run_v2_circuit");
        vkeyHash = bytes32(0x46e72119ce99272ddff09e0780b472fdc612ca799c245eea223b27e57a5f9cec);
        logMaxNumClaims = 4;

        mockGrant = new WLDGrant();
        aggregation = new WorldcoinAggregationV2Exposed({
            axiomV2QueryAddress: axiomV2QueryAddress,
            callbackSourceChainId: uint64(block.chainid),
            querySchema: querySchema,
            vkeyHash: vkeyHash,
            logMaxNumClaims: logMaxNumClaims,
            wldToken: wldToken,
            // Identity Manager
            rootValidator: rootValidator,
            grant: address(mockGrant)
        });

        deal(wldToken, address(aggregation), 100e18);

        string memory input = vm.readFile(inputPath);
        grantId = uint256(input.readUint(".grant_id"));
        root = input.readUint(".root");

        numClaims = input.readUint(".num_proofs");
        for (uint256 i = 0; i != numClaims; ++i) {
            string memory path = string.concat(".claims[", toString(i), "]");
            bytes32 receiver = bytes32(input.readUint(string.concat(path, ".receiver")));
            bytes32 nullifierHash = bytes32(input.readUint(string.concat(path, ".nullifier_hash")));
            receivers.push(_toAddress(receiver));
            nullifierHashes.push(nullifierHash);
        }

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

    function _parseResults(bytes32[] memory results)
        internal
        pure
        returns (bytes32 _vkeyHash, uint256 _grantId, uint256 _root, bytes32 _claimsRoot)
    {
        _vkeyHash = results[0];
        _grantId = uint256(results[1]);
        _root = uint256(results[2]);
        _claimsRoot = results[3];
    }

    function _toAddress(bytes32 input) private pure returns (address out) {
        /// @solidity memory-safe-assembly
        assembly {
            out := input
        }
    }
}
