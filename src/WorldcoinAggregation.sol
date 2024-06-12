// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { AxiomV2Client } from "@axiom-crypto/v2-periphery/client/AxiomV2Client.sol";

contract WorldcoinAggregation is AxiomV2Client {
    /// @dev The unique identifier of the circuit accepted by this contract.
    bytes32 immutable QUERY_SCHEMA;

    /// @dev The chain ID of the chain whose data the callback is expected to be called from.
    uint64 immutable SOURCE_CHAIN_ID;

    /// @dev The verification key hash of the Groth16 circuit.
    bytes32 immutable VKEY_HASH;

    /// @dev The maximum number of claims that can be made in a single call.
    uint256 immutable MAX_NUM_CLAIMS;

    /// @dev Whether a nullifier hash has been used already. Used to prevent double-signaling
    mapping(bytes32 nullifierHash => bool) public nullifierHashes;

    /// @notice Emitted when a grant is successfully claimed
    /// @param receiver The address that received the tokens
    event GrantClaimed(uint256 grantId, address receiver);

    /// @dev Root validation failed
    error InvalidRoot();

    /// @dev `numClaims` must be less than or equal to `MAX_NUM_CLAIMS`
    error TooManyClaims();

    /// @dev Grant id cannot be zero
    error InvalidGrantId();

    /// @dev Source chain ID does not match
    error SourceChainIdNotMatching();

    /// @dev Invalid query schema
    error InvalidQuerySchema();

    /// @dev The verification key of the query must match the contract's
    error InvalidVkeyHash();

    /// @dev Axiom result array must have `4 + 2 * MAX_NUM_CLAIMS` items.
    /// We expect the results returned from the Axiom query to be:
    ///
    /// axiomResults[0]: vkeyHash
    /// axiomResults[1]: grantId
    /// axiomResults[2]: root
    /// axiomResults[3]: numClaims
    /// axiomResults[idx] for idx in [4, 4 + numClaims): receivers
    /// axiomResults[idx] for idx in [4 + MAX_NUM_CLAIMS, 4 + MAX_NUM_CLAIMS + numClaims): claimedNullifierHashes
    error InvalidNumberOfResults();

    /// @notice Construct a new AverageBalance contract.
    /// @param  axiomV2QueryAddress The address of the AxiomV2Query contract.
    /// @param  callbackSourceChainId The ID of the chain the query reads from.
    /// @param  querySchema The schema of the query.
    /// @param  vkeyHash The verification key hash of the Groth16 circuit.
    /// @param  maxNumClaims The number of claims that can be made in a single call.
    constructor(
        address axiomV2QueryAddress,
        uint64 callbackSourceChainId,
        bytes32 querySchema,
        bytes32 vkeyHash,
        uint256 maxNumClaims
    ) AxiomV2Client(axiomV2QueryAddress) {
        QUERY_SCHEMA = querySchema;
        SOURCE_CHAIN_ID = callbackSourceChainId;
        VKEY_HASH = vkeyHash;
        MAX_NUM_CLAIMS = maxNumClaims;
    }

    /// @notice Reverts if the root is not valid
    /// @param root The root to validate
    function _requireValidRoot(bytes32 root) internal view {
        if (root == 0) {
            revert InvalidRoot();
        }

        // TODO: Add validation logic
    }

    /// @inheritdoc AxiomV2Client
    function _validateAxiomV2Call(
        AxiomCallbackType, // callbackType,
        uint64 sourceChainId,
        address, // caller,
        bytes32 querySchema,
        uint256, // queryId,
        bytes calldata // extraData
    ) internal view override {
        if (sourceChainId != SOURCE_CHAIN_ID) {
            revert SourceChainIdNotMatching();
        }
        if (querySchema != QUERY_SCHEMA) {
            revert InvalidQuerySchema();
        }
    }

    /// @inheritdoc AxiomV2Client
    function _axiomV2Callback(
        uint64, // sourceChainId,
        address, // caller,
        bytes32, // querySchema,
        uint256, // queryId,
        bytes32[] calldata axiomResults,
        bytes calldata // extraData
    ) internal override {
        if (axiomResults.length != 4 + 2 * MAX_NUM_CLAIMS) {
            revert InvalidNumberOfResults();
        }

        bytes32 vkeyHash = _unsafeCalldataAccess(axiomResults, 0);
        if (vkeyHash != VKEY_HASH) {
            revert InvalidVkeyHash();
        }

        uint256 grantId = uint256(_unsafeCalldataAccess(axiomResults, 1));
        if (grantId == 0) {
            revert InvalidGrantId();
        }

        bytes32 root = _unsafeCalldataAccess(axiomResults, 2);
        _requireValidRoot(root);

        uint256 numClaims = uint256(_unsafeCalldataAccess(axiomResults, 3));
        if (numClaims > MAX_NUM_CLAIMS) {
            revert TooManyClaims();
        }

        for (uint256 i = 0; i != numClaims;) {
            address receiver = _toAddress(_unsafeCalldataAccess(axiomResults, 4 + i));
            bytes32 claimedNullifierHash = _unsafeCalldataAccess(axiomResults, 4 + MAX_NUM_CLAIMS + i);

            if (!nullifierHashes[claimedNullifierHash] && receiver != address(0)) {
                nullifierHashes[claimedNullifierHash] = true;

                // TODO: actually transfer the grant funds

                emit GrantClaimed(grantId, receiver);
            }

            // Claimed nullifier hashes are skipped
            unchecked {
                ++i;
            }
        }
    }

    function _toAddress(bytes32 input) private pure returns (address out) {
        /// @solidity memory-safe-assembly
        assembly {
            out := input
        }
    }

    /// @dev Access a calldata array without the overhead of an out of bounds
    /// check. Should only be used when `index` is known to be within bounds.
    /// @param array The array to access
    function _unsafeCalldataAccess(bytes32[] calldata array, uint256 index) private pure returns (bytes32 out) {
        /// @solidity memory-safe-assembly
        assembly {
            out := calldataload(add(array.offset, mul(index, 0x20)))
        }
    }
}
