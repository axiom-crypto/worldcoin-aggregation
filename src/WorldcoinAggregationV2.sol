// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { AxiomV2Client } from "@axiom-crypto/v2-periphery/client/AxiomV2Client.sol";

import { IERC20 } from "./interfaces/IERC20.sol";
import { IRootValidator } from "./interfaces/IRootValidator.sol";
import { IGrant } from "./interfaces/IGrant.sol";

/// @notice V2 of the aggregation contract implements a two-step process to
/// distribute the grant. The SNARK verification callback will only commit a
/// root for the receivers the prove against. Once the commitment is complete,
/// the burden is on the receiver (or someone their behalf) to prove into the
/// root and transfer the grant to the receiver.
contract WorldcoinAggregationV2 is AxiomV2Client {
    /// @dev The unique identifier of the circuit accepted by this contract.
    bytes32 immutable QUERY_SCHEMA;

    /// @dev The chain ID of the chain whose data the callback is expected to be called from.
    uint64 immutable SOURCE_CHAIN_ID;

    /// @dev The verification key hash of the Groth16 circuit.
    bytes32 immutable VKEY_HASH;

    /// @dev The base-2 logarithm of the maximum number of claims that can be
    /// made in a single call.
    uint256 immutable LOG_MAX_NUM_CLAIMS;

    /// @dev The WLD token contract
    IERC20 public immutable WLD;

    /// @dev The contract which can validate World ID roots
    IRootValidator public immutable ROOT_VALIDATOR;

    /// @dev The grant contract
    IGrant public immutable GRANT;

    /// @dev Whether a nullifier hash has been used already. Used to prevent
    /// double-signaling
    mapping(bytes32 nullifierHash => bool) public nullifierHashes;

    /// @dev Valid Merkle roots of claims, indexed by grantId and root
    mapping(uint256 grantId => mapping(uint256 root => mapping(bytes32 claimsRoot => bool))) public validClaimsRoots;

    /// @notice Emitted when a grant is successfully claimed
    /// @param receiver The address that received the tokens
    event GrantClaimed(uint256 grantId, address receiver);

    /// @dev `logMaxNumClaims` cannot be greater than 32
    error InvalidLogMaxNumClaims();

    /// @dev Root validation failed
    error InvalidRoot();

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
    error InvalidNumberOfResults();

    /// @notice Construct a new AverageBalance contract.
    /// @param  axiomV2QueryAddress The address of the AxiomV2Query contract.
    /// @param  callbackSourceChainId The ID of the chain the query reads from.
    /// @param  querySchema The schema of the query.
    /// @param  vkeyHash The verification key hash of the Groth16 circuit.
    /// @param  logMaxNumClaims The number of claims that can be made in a
    /// single call.
    constructor(
        address axiomV2QueryAddress,
        uint64 callbackSourceChainId,
        bytes32 querySchema,
        bytes32 vkeyHash,
        uint256 logMaxNumClaims,
        address wldToken,
        address rootValidator,
        address grant
    ) AxiomV2Client(axiomV2QueryAddress) {
        if (logMaxNumClaims > 32) revert InvalidLogMaxNumClaims();

        QUERY_SCHEMA = querySchema;
        SOURCE_CHAIN_ID = callbackSourceChainId;
        VKEY_HASH = vkeyHash;
        LOG_MAX_NUM_CLAIMS = logMaxNumClaims;
        WLD = IERC20(wldToken);
        ROOT_VALIDATOR = IRootValidator(rootValidator);
        GRANT = IGrant(grant);
    }

    /// @notice Claim a grant
    /// @param grantId The grant ID to claim
    /// @param root The root of the Merkle tree (signup-sequencer or
    /// world-id-contracts provides this)
    /// @param receiver The address that will receive the tokens (this is also
    /// the signal of the ZKP)
    /// @param nullifierHash The nullifier for the proof, preventing double
    /// signaling
    /// @param leaves The Merkle proof of the claim
    /// @param isLeftBytes The isLeft bytes of the Merkle proof. This is more
    /// efficient than a bool[] in calldata since it will only occupy one slot.
    /// The bytes should really just be zero or one, but anything non-zero will
    /// get coerced to true. The first index (the leaf) should map to the most
    /// significant byte. For example, a proof of length 4 with all `isLeft =
    /// true` would look like:
    /// index | 00 01 02 03 04 .. 31
    /// value | 01 01 01 01 00 00 00
    ///
    /// The resulting `isLeftBytes` would be
    /// 0x0101010100000000000000000000000000000000000000000000000000000000
    function claim(
        uint256 grantId,
        uint256 root,
        address receiver,
        bytes32 nullifierHash,
        bytes32[] calldata leaves,
        bytes32 isLeftBytes
    ) external {
        if (nullifierHashes[nullifierHash]) revert NullifierHashAlreadyUsed();
        if (receiver == address(0)) revert InvalidReceiver();
        GRANT.checkValidity(grantId);

        uint256 length = leaves.length;
        if (length != LOG_MAX_NUM_CLAIMS) revert InvalidMerkleProofLength();

        bytes32 runningHash = _efficientPackedHash(receiver, nullifierHash);
        for (uint256 i = 0; i != length;) {
            // Unsafe access OK here since we know i is bounded by the length
            bytes32 node = _unsafeBytes32Access(leaves, i);

            // Access the byte without an overflow check (safe because length is
            // bounded by logMaxNumClaims which is bounded by 32 in the
            // constructor). Then coerce to bool.
            bool isLeft = _toBool(_unsafeByteAccess(isLeftBytes, i));

            if (isLeft) runningHash = _efficientHash(node, runningHash);
            else runningHash = _efficientHash(runningHash, node);

            // forgefmt: disable-next-line
            unchecked { ++i; }
        }

        if (!validClaimsRoots[grantId][root][runningHash]) revert InvalidMerkleProof();

        nullifierHashes[nullifierHash] = true;

        uint256 grantAmount = GRANT.getAmount(grantId);

        WLD.transfer(receiver, grantAmount);

        emit GrantClaimed(grantId, receiver);
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
        if (sourceChainId != SOURCE_CHAIN_ID) revert SourceChainIdNotMatching();
        if (querySchema != QUERY_SCHEMA) revert InvalidQuerySchema();
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
        /// We expect the results returned from the Axiom query to be:
        ///
        /// axiomResults[0]: vkeyHash
        /// axiomResults[1]: grantId
        /// axiomResults[2]: root
        /// axiomResults[3]: claimsRoot
        if (axiomResults.length != 4) revert InvalidNumberOfResults();

        // Unsafe accesses OK here since we know the length is 4

        bytes32 vkeyHash = _unsafeBytes32Access(axiomResults, 0);
        if (vkeyHash != VKEY_HASH) revert InvalidVkeyHash();

        uint256 grantId = uint256(_unsafeBytes32Access(axiomResults, 1));
        GRANT.checkValidity(grantId);

        uint256 root = uint256(_unsafeBytes32Access(axiomResults, 2));
        ROOT_VALIDATOR.requireValidRoot(root);

        bytes32 claimsRoot = _unsafeBytes32Access(axiomResults, 3);

        validClaimsRoots[grantId][root][claimsRoot] = true;
    }

    /// @dev Hashes an address and a uint256 without triggering memory
    /// expansion. This is done packed -- equivalent to
    /// keccak256(abi.encodePacked(a, b))
    ///
    /// @param a The address to hash
    /// @param b The bytes32 to hash
    function _efficientPackedHash(address a, bytes32 b) internal pure returns (bytes32 out) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            out := keccak256(0x0c, 0x34)
        }
    }

    /// @dev Hashes two bytes32 words without triggering memory expansion
    /// @param a The first word
    /// @param b The second word
    function _efficientHash(bytes32 a, bytes32 b) internal pure returns (bytes32 out) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            out := keccak256(0x00, 0x40)
        }
    }

    /// @dev Access a calldata bytes32 array without the overhead of an out of
    /// bounds check. Should only be used when `index` is known to be within
    /// bounds.
    /// @param array The array to access
    /// @param index The index to access
    /// @return out The value at the given index
    function _unsafeBytes32Access(bytes32[] calldata array, uint256 index) internal pure returns (bytes32 out) {
        /// @solidity memory-safe-assembly
        assembly {
            out := calldataload(add(array.offset, mul(index, 0x20)))
        }
    }

    /// @dev Access a single byte of a bytes32 without an overflow check. Should
    /// only be used when `index` is known to be less than 32.
    /// @param value The bytes32 to access
    /// @param index The index to access
    /// @return out The value at the given index
    function _unsafeByteAccess(bytes32 value, uint256 index) internal pure returns (bytes32 out) {
        /// @solidity memory-safe-assembly
        assembly {
            out := byte(index, value)
        }
    }

    /// @dev Coerce a bytes32 to a bool. Anything non-zero will be coerced to
    /// true.
    /// @param input The bytes32 to coerce
    /// @return out The coerced bool
    function _toBool(bytes32 input) internal pure returns (bool out) {
        /// @solidity memory-safe-assembly
        assembly {
            out := input
        }
    }
}
