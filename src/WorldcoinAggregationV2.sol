// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { AxiomV2Client } from "@axiom-crypto/v2-periphery/client/AxiomV2Client.sol";

import { safeconsole as console } from "forge-std/safeconsole.sol";
import { console2 } from "forge-std/console2.sol";

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
    mapping(bytes32 nullifierHash => bool) public nullifierHashes;

    /// @dev Valid Merkle roots of claims, indexed by grantId and root
    mapping(uint256 grantId => mapping(bytes32 root => mapping(bytes32 claimsRoot => bool))) public validClaimsRoots;

    /// @notice Emitted when a grant is successfully claimed
    /// @param receiver The address that received the tokens
    event GrantClaimed(uint256 grantId, address receiver);

    /// @dev Root validation failed
    error InvalidRoot();

    /// @dev Grant id cannot be zero
    error InvalidGrantId();

    /// @dev Nullifier hash already used
    error NullifierHashAlreadyUsed();

    /// @dev Receiver cannot be the zero address
    error InvalidReceiver();

    /// @dev Merkle proofs length must match `LOG_MAX_NUM_CLAIMS`
    error InvalidMerkleProofLength();

    /// @dev Merkle proof validation failed
    error InvalidMerkleProof();

    /// @dev Source chain ID does not match
    error SourceChainIdNotMatching();

    /// @dev Invalid query schema
    error InvalidQuerySchema();

    /// @dev The verification key of the query must match the contract's
    error InvalidVkeyHash();

    /// @dev Axiom result array must have exactly four items.
    /// We expect the results returned from the Axiom query to be:
    ///
    /// axiomResults[0]: vkeyHash
    /// axiomResults[1]: grantId
    /// axiomResults[2]: root
    /// axiomResults[3]: claimsRoot
    error InvalidNumberOfResults();

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
        bytes32 root,
        address receiver,
        bytes32 nullifierHash,
        bytes32[] calldata merkleProof
    ) external {
        _requireValidRoot(root);
        if (grantId == 0) {
            revert InvalidGrantId();
        }
        if (nullifierHashes[nullifierHash]) {
            revert NullifierHashAlreadyUsed();
        }
        if (receiver == address(0)) {
            revert InvalidReceiver();
        }

        uint256 length = merkleProof.length;
        if (merkleProof.length != LOG_MAX_NUM_CLAIMS) {
            revert InvalidMerkleProofLength();
        }

        bytes32 runningHash = _efficientHash(receiver, nullifierHash);
        for (uint256 i = 0; i != length;) {
            // Unsafe access OK here since we know i is bounded by the length
            bytes32 node = _unsafeCalldataAccess(merkleProof, i);

            console.log(node);

            if (runningHash < node) {
                runningHash = _efficientHash(runningHash, node);
            } else {
                runningHash = _efficientHash(node, runningHash);
            }

            unchecked {
                ++i;
            }
        }

        if (!validClaimsRoots[grantId][root][runningHash]) {
            revert InvalidMerkleProof();
        }

        nullifierHashes[nullifierHash] = true;

        // TODO: actually transfer the grant funds

        emit GrantClaimed(grantId, receiver);
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
        if (axiomResults.length != 4) {
            revert InvalidNumberOfResults();
        }

        // Unsafe accesses OK here since we know the length is 4

        bytes32 vkeyHash = _unsafeCalldataAccess(axiomResults, 0);
        if (vkeyHash != VKEY_HASH) {
            revert InvalidVkeyHash();
        }

        uint256 grantId = uint256(_unsafeCalldataAccess(axiomResults, 1));
        bytes32 root = _unsafeCalldataAccess(axiomResults, 2);
        bytes32 claimsRoot = _unsafeCalldataAccess(axiomResults, 3);

        console.log(grantId, root);
        console2.logBytes32(claimsRoot);

        validClaimsRoots[grantId][root][claimsRoot] = true;
    }

    /// @dev Hashes an address and a uint256 without trigger memory expansion.
    /// This is done packed -- equivalent to keccak256(abi.encodePacked(a, b))
    ///
    /// @param a The address to hash
    /// @param b The bytes32 to hash
    function _efficientHash(address a, bytes32 b) private pure returns (bytes32 out) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            out := keccak256(0x0c, 0x34)
        }
    }

    /// @dev Hashes two bytes32 words without trigger memory expansion
    /// @param a The first word
    /// @param b The second word
    function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 out) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            out := keccak256(0x00, 0x40)
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
