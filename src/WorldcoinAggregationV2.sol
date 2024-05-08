// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { AxiomV2Client } from "@axiom-crypto/v2-periphery/client/AxiomV2Client.sol";

contract WorldcoinAggregationV2 is AxiomV2Client {
    /// @dev The unique identifier of the circuit accepted by this contract.
    bytes32 immutable QUERY_SCHEMA;

    /// @dev The chain ID of the chain whose data the callback is expected to be called from.
    uint64 immutable SOURCE_CHAIN_ID;

    /// @dev The verification key hash of the Groth16 circuit.
    bytes32 immutable VKEY_HASH;

    /// @dev The base-2 logarithm of the maximum number of claims that can be made in a single call.
    uint256 immutable LOG_MAX_NUM_CLAIMS;

    /// @dev Whether a nullifier hash has been used already. Used to prevent double-signaling
    mapping(uint256 => bool) public nullifierHashes;

    /// @dev Valid Merkle roots of claims, indexed by grantId and root
    mapping(uint256 => mapping(uint256 => mapping(bytes32 => bool))) public validClaimsRoots;

    /// @notice Emitted when a grant is successfully claimed
    /// @param receiver The address that received the tokens
    event GrantClaimed(uint256 grantId, address receiver);

    /// @notice Construct a new AverageBalance contract.
    /// @param  axiomV2QueryAddress The address of the AxiomV2Query contract.
    /// @param  callbackSourceChainId The ID of the chain the query reads from.
    /// @param  querySchema The schema of the query.
    /// @param  vkeyHash The verification key hash of the Groth16 circuit.
    /// @param  logMaxNumClaims The number of claims that can be made in a single call.
    constructor(
        address axiomV2QueryAddress,
        uint64 callbackSourceChainId,
        bytes32 querySchema,
        bytes32 vkeyHash,
        uint256 logMaxNumClaims
    ) AxiomV2Client(axiomV2QueryAddress) {
        QUERY_SCHEMA = querySchema;
        SOURCE_CHAIN_ID = callbackSourceChainId;
        VKEY_HASH = vkeyHash;
        LOG_MAX_NUM_CLAIMS = logMaxNumClaims;
    }

    /// @notice Claim a grant
    /// @param grantId The grant ID to claim
    /// @param root The root of the Merkle tree (signup-sequencer or world-id-contracts provides this)
    /// @param receiver The address that will receive the tokens (this is also the signal of the ZKP)
    /// @param nullifierHash The nullifier for the proof, preventing double signaling
    /// @param merkleProof The Merkle proof of the claim
    function claim(
        uint256 grantId,
        uint256 root,
        address receiver,
        uint256 nullifierHash,
        bytes32[] calldata merkleProof
    ) external {
        _requireValidRoot(root);
        _requireValidGrant(grantId);

        require(!nullifierHashes[nullifierHash], "Nullifier hash already used");
        require(receiver != address(0), "Invalid receiver");
        require(merkleProof.length == LOG_MAX_NUM_CLAIMS, "Invalid Merkle proof length");

        // TODO: gas optimize by doing Keccak in assembly
        bytes32 runningHash = keccak256(abi.encodePacked(receiver, nullifierHash));
        for (uint256 i = 0; i < merkleProof.length; i++) {
            if (runningHash < merkleProof[i]) {
                runningHash = keccak256(abi.encodePacked(runningHash, merkleProof[i]));
            } else {
                runningHash = keccak256(abi.encodePacked(merkleProof[i], runningHash));
            }
        }
        require(validClaimsRoots[grantId][root][runningHash], "Invalid Merkle proof");

        nullifierHashes[nullifierHash] = true;

        // TODO: actually transfer the grant funds

        emit GrantClaimed(grantId, receiver);
    }

    /// @notice Record claimsRoot for multiple airdrop claims
    /// @param grantId The grant ID to claim
    /// @param root The root of the Merkle tree (signup-sequencer or world-id-contracts provides this)
    /// @param claimsRoot The root of the Merkle tree of the claims
    function _recordClaimsRoot(uint256 grantId, uint256 root, bytes32 claimsRoot) internal {
        validClaimsRoots[grantId][root][claimsRoot] = true;
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
        require(axiomResults.length == 4, "Invalid number of results");
        // We expect the results returned from the Axiom query to be:
        // axiomResults[0]: vkeyHash
        // axiomResults[1]: grantId
        // axiomResults[2]: root
        // axiomResults[3]: claimsRoot

        bytes32 vkeyHash = axiomResults[0];
        uint256 grantId = uint256(axiomResults[1]);
        uint256 root = uint256(axiomResults[2]);
        bytes32 claimsRoot = axiomResults[3];

        require(vkeyHash == VKEY_HASH, "Invalid vkey hash");

        _recordClaimsRoot(grantId, root, claimsRoot);
    }
}
