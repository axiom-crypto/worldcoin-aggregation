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
    mapping(uint256 => bool) public nullifierHashes;

    /// @notice Emitted when a grant is successfully claimed
    /// @param receiver The address that received the tokens
    event GrantClaimed(uint256 grantId, address receiver);

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

    /// @notice Claim multiple airdrops
    /// @param numClaims The number of claims to make
    /// @param grantId The grant ID to claim
    /// @param receivers The addresses that will receive the tokens (this is also the signal of the ZKP)
    /// @param root The root of the Merkle tree (signup-sequencer or world-id-contracts provides this)
    /// @param claimedNullifierHashes The nullifiers for the proofs, preventing double signaling
    function _batchClaim(
        uint256 numClaims,
        uint256 grantId,
        address[] memory receivers,
        uint256 root,
        uint256[] memory claimedNullifierHashes
    ) internal {
        _requireValidRoot(root);

        _requireValidGrant(grantId);

        require(receivers.length == numClaims, "Invalid number of receivers");
        require(claimedNullifierHashes.length == numClaims, "Invalid number of nullifiers");

        for (uint256 i = 0; i < numClaims; i++) {
            if (!nullifierHashes[claimedNullifierHashes[i]] && receivers[i] != address(0)) {
                nullifierHashes[claimedNullifierHashes[i]] = true;
                emit GrantClaimed(grantId, receivers[i]);
            }
        }
    }

    /// @notice Reverts if the root is not valid
    /// @param root The root to validate
    function _requireValidRoot(uint256 root) internal view {
        require(root != 0, "Invalid root");

        // TODO: Add validation logic
    }

    /// @notice Reverts if the grant is not valid
    /// @param grantId The grant ID to validate
    function _requireValidGrant(uint256 grantId) internal view {
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
        // Add your validation logic here for checking the callback responses
        require(sourceChainId == SOURCE_CHAIN_ID, "Source chain ID does not match");
        require(querySchema == QUERY_SCHEMA, "Invalid query schema");
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
        require(axiomResults.length == 4 + 2 * MAX_NUM_CLAIMS, "Invalid number of results");
        // We expect the results returned from the Axiom query to be:
        // axiomResults[0]: vkeyHash
        // axiomResults[1]: grantId
        // axiomResults[2]: root
        // axiomResults[3]: numClaims
        // axiomResults[idx] for idx in [4, 4 + numClaims): receivers
        // axiomResults[idx] for idx in [4 + MAX_NUM_CLAIMS, 4 + MAX_NUM_CLAIMS + numClaims): claimedNullifierHashes

        bytes32 vkeyHash = axiomResults[0];
        uint256 grantId = uint256(axiomResults[1]);
        uint256 root = uint256(axiomResults[2]);
        uint256 numClaims = uint256(axiomResults[3]);

        require(vkeyHash == VKEY_HASH, "Invalid vkey hash");
        require(numClaims <= MAX_NUM_CLAIMS, "Too many claims");

        address[] memory receivers = new address[](numClaims);
        uint256[] memory claimedNullifierHashes = new uint256[](numClaims);
        for (uint256 idx; idx < numClaims; idx++) {
            receivers[idx] = address(uint160(uint256(axiomResults[4 + idx])));
        }
        for (uint256 idx; idx < numClaims; idx++) {
            claimedNullifierHashes[idx] = uint256(axiomResults[4 + MAX_NUM_CLAIMS + idx]);
        }

        _batchClaim(numClaims, grantId, receivers, root, claimedNullifierHashes);
    }
}
