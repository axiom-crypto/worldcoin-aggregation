// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { AxiomTest } from "@axiom-crypto/axiom-std/AxiomTest.sol";

import { toString } from "./Utils.sol";
import { WorldcoinAggregation } from "../../src/WorldcoinAggregation.sol";

import { stdJson as StdJson } from "forge-std/Test.sol";

contract WorldcoinAggregationExposed is WorldcoinAggregation {
    constructor(
        address axiomV2QueryAddress,
        uint64 callbackSourceChainId,
        bytes32 querySchema,
        bytes32 vkeyHash,
        uint256 maxNumClaims,
        address wldToken,
        address rootValidator
    )
        WorldcoinAggregation(
            axiomV2QueryAddress,
            callbackSourceChainId,
            querySchema,
            vkeyHash,
            maxNumClaims,
            wldToken,
            rootValidator
        )
    { }

    function toAddress(bytes32 input) external pure returns (address) {
        return _toAddress(input);
    }

    /// @dev Access a calldata array without the overhead of an out of bounds
    /// check. Should only be used when `index` is known to be within bounds.
    /// @param array The array to access
    function unsafeCalldataAccess(bytes32[] calldata array, uint256 index) external pure returns (bytes32) {
        return _unsafeCalldataAccess(array, index);
    }
}

contract WorldcoinAggregationHelper is AxiomTest {
    using StdJson for string;

    struct AxiomInput {
        bytes32 e;
    }

    WorldcoinAggregationExposed aggregation;
    bytes32 querySchema;

    bytes32 vkeyHash;
    uint256 grantId;
    uint256 root;
    uint256 maxNumClaims;

    address[] receivers;
    bytes32[] nullifierHashes;

    // The address here doesn't matter much for testing purposes. So we
    // just use Sepolia-WETH
    address wldToken = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
    address rootValidator = 0x928a514350A403e2f5e3288C102f6B1CCABeb37C;

    string inputPath = "client-circuit/data/worldcoin_input.json";

    function setUp() public virtual {
        _createSelectForkAndSetupAxiom("provider");

        querySchema =
            axiomVm.readRustCircuit("client-circuit/Cargo.toml", inputPath, "client-circuit/data", "run_v1_circuit");
        vkeyHash = bytes32(0x46e72119ce99272ddff09e0780b472fdc612ca799c245eea223b27e57a5f9cec);
        maxNumClaims = 16;
        aggregation = new WorldcoinAggregationExposed({
            axiomV2QueryAddress: axiomV2QueryAddress,
            callbackSourceChainId: uint64(block.chainid),
            querySchema: querySchema,
            vkeyHash: vkeyHash,
            maxNumClaims: maxNumClaims,
            wldToken: wldToken,
            // Identity Manager
            rootValidator: rootValidator
        });

        // Fund the grant
        deal(wldToken, address(aggregation), 100e18);

        string memory input = vm.readFile(inputPath);
        grantId = uint256(input.readUint(".grant_id"));
        root = input.readUint(".root");

        uint256 numClaims = input.readUint(".num_proofs");
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

    // Axiom result array must have `4 + 2 * MAX_NUM_CLAIMS` items.
    // We expect the results returned from the Axiom query to be:
    //
    // axiomResults[0]: vkeyHash
    // axiomResults[1]: grantId
    // axiomResults[2]: root
    // axiomResults[3]: numClaims
    // axiomResults[idx] for idx in [4, 4 + numClaims): receivers
    // axiomResults[idx] for idx in [4 + MAX_NUM_CLAIMS, 4 + MAX_NUM_CLAIMS + numClaims): claimedNullifierHashes
    function _parseResults(bytes32[] memory results)
        internal
        view
        returns (
            bytes32 _vkeyHash,
            uint256 _grantId,
            uint256 _root,
            uint256 numClaims,
            address[] memory _receivers,
            bytes32[] memory _nullifierHashes
        )
    {
        _vkeyHash = results[0];
        _grantId = uint256(results[1]);
        _root = uint256(results[2]);
        numClaims = uint256(results[3]);

        _receivers = new address[](numClaims);
        _nullifierHashes = new bytes32[](numClaims);

        for (uint256 i = 0; i != numClaims; ++i) {
            _receivers[i] = _toAddress(results[4 + i]);
            _nullifierHashes[i] = results[4 + maxNumClaims + i];
        }
    }

    function _toAddress(bytes32 input) internal pure returns (address out) {
        /// @solidity memory-safe-assembly
        assembly {
            out := input
        }
    }
}
