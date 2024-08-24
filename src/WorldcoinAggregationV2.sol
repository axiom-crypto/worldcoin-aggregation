// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { IERC20 } from "./interfaces/IERC20.sol";
import { IRootValidator } from "./interfaces/IRootValidator.sol";
import { IGrant } from "./interfaces/IGrant.sol";

/// @notice V2 of the aggregation contract implements a two-step process to
/// distribute the grant. The SNARK verification callback will only commit a
/// root for the receivers the prove against. Once the commitment is complete,
/// the burden is on the receiver (or someone their behalf) to prove into the
/// root and transfer the grant to the receiver.
contract WorldcoinAggregationV2 {
    uint256 public constant VKEY_HASH_HI_OFFSET = 12 * 32;
    uint256 public constant VKEY_HASH_LO_OFFSET = 13 * 32;
    uint256 public constant ROOT_OFFSET = 14 * 32;
    uint256 public constant NUM_CLAIMS_OFFSET = 15 * 32;
    uint256 public constant CLAIMS_ROOT_HI_OFFSET = 16 * 32;
    uint256 public constant CLAIMS_ROOT_LO_OFFSET = 17 * 32;

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

    /// @dev The verifier contract
    address public immutable VERIFIER_ADDRESS;

    /// @dev If `PROVER` is not the zero address, only `PROVER` can call
    /// `distributeGrants`.
    address public immutable PROVER;

    /// @dev Whether a nullifier hash has been used already. Used to prevent
    /// double-signaling
    mapping(uint256 nullifierHash => bool) public nullifierHashes;

    /// @dev Valid Merkle roots of claims, indexed by root
    mapping(uint256 root => mapping(bytes32 claimsRoot => bool)) public validClaimsRoots;

    /// @notice Emitted when a grant is successfully claimed
    /// @param receiver The address that received the tokens
    event GrantClaimed(uint256 grantId, address receiver);

    /// @dev Only the prover can call
    error OnlyProver();

    /// @dev `logMaxNumClaims` cannot be greater than 32
    error InvalidLogMaxNumClaims();

    /// @dev SNARK verification failed
    error InvalidProof();

    /// @dev Nullifier hash already used
    error NullifierHashAlreadyUsed();

    /// @dev Receiver cannot be the zero address
    error InvalidReceiver();

    /// @dev Merkle proofs length must match `LOG_MAX_NUM_CLAIMS`
    error InvalidMerkleProofLength();

    /// @dev Merkle proof validation failed
    error InvalidMerkleProof();

    /// @dev Number of claims must be less than or equal to `2 ** LOG_MAX_NUM_CLAIMS`
    error InvalidNumberOfClaims();

    /// @dev The verification key of the query must match the contract's
    error InvalidVkeyHash();

    modifier onlyProver() {
        if (PROVER != address(0) && msg.sender != PROVER) revert OnlyProver();
        _;
    }

    /// @notice Construct a new WorldcoinAggregationV2 contract.
    /// @param  vkeyHash The verification key hash of the Groth16 circuit.
    /// @param  logMaxNumClaims The number of claims that can be made in a
    /// single call.
    /// @param wldToken It is expected that this token reverts on transfer
    /// failures.
    /// @param verifierAddress The address of the verifier contract
    /// @param prover The address of the prover contract
    constructor(
        bytes32 vkeyHash,
        uint256 logMaxNumClaims,
        address wldToken,
        address rootValidator,
        address grant,
        address verifierAddress,
        address prover
    ) {
        if (logMaxNumClaims > 32) revert InvalidLogMaxNumClaims();

        VKEY_HASH = vkeyHash;
        LOG_MAX_NUM_CLAIMS = logMaxNumClaims;
        WLD = IERC20(wldToken);
        ROOT_VALIDATOR = IRootValidator(rootValidator);
        GRANT = IGrant(grant);

        VERIFIER_ADDRESS = verifierAddress;
        PROVER = prover;
    }

    /// @notice Claim a grant
    /// @param grantId The grant ID to claim
    /// @param root The root of the Merkle tree (signup-sequencer or
    /// world-id-contracts provides this)
    /// @param receiver The address that will receive the tokens (this is also
    /// the signal of the ZKP)
    /// @param nullifierHash The nullifier for the proof, preventing double
    /// signaling
    /// @param sisterNodes The Merkle proof of the claim
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
        uint256 nullifierHash,
        bytes32[] calldata sisterNodes,
        bytes32 isLeftBytes
    ) external {
        if (nullifierHashes[nullifierHash]) revert NullifierHashAlreadyUsed();
        if (receiver == address(0)) revert InvalidReceiver();
        GRANT.checkValidity(grantId);

        uint256 length = sisterNodes.length;
        if (length != LOG_MAX_NUM_CLAIMS) revert InvalidMerkleProofLength();

        bytes32 runningHash = keccak256(abi.encodePacked(grantId, receiver, nullifierHash));
        for (uint256 i = 0; i != length;) {
            // Unsafe access OK here since we know i is bounded by the length
            bytes32 node = _unsafeCalldataArrayAccess(sisterNodes, i);

            // Access the byte without an overflow check (safe because length is
            // bounded by logMaxNumClaims which is bounded by 32 in the
            // constructor). Then coerce to bool.
            bool isLeft = _toBool(_unsafeByteAccess(isLeftBytes, i));

            if (isLeft) runningHash = _efficientHash(node, runningHash);
            else runningHash = _efficientHash(runningHash, node);

            // forgefmt: disable-next-line
            unchecked { ++i; }
        }

        if (!validClaimsRoots[root][runningHash]) revert InvalidMerkleProof();

        nullifierHashes[nullifierHash] = true;

        uint256 grantAmount = GRANT.getAmount(grantId);

        WLD.transfer(receiver, grantAmount);

        emit GrantClaimed(grantId, receiver);
    }

    /// @notice Validate a claims root
    /// @param proof The SNARK proof
    function validateClaimsRoot(bytes calldata proof) external onlyProver {
        // Proof must have minimuim 18 words.
        // We expect the proof to be structured as such:
        //
        // proof[0..12 * 32]: reserved for proof verification data used with the
        // pairing precompile
        //
        // proof[12 * 32..13 * 32]: vkeyHash Hi
        // proof[13 * 32..14 * 32]: vkeyHash Lo
        // proof[14 * 32..15 * 32]: root
        // proof[15 * 32..16 * 32]: numClaims
        // proof[16 * 32..17 * 32]: claimsRoot Hi
        // proof[17 * 32..18 * 32]: claimsRoot Lo
        //
        // if (proof.length < 18 * 32) revert InvalidProof();
        //
        // proof[18 * 32..]: Proof used in SNARK verification

        if (proof.length < 18 * 32) revert InvalidProof();

        bytes32 vkeyHash = _unsafeCalldataBytesAccess(proof, VKEY_HASH_HI_OFFSET) << 128
            | _unsafeCalldataBytesAccess(proof, VKEY_HASH_LO_OFFSET);

        if (vkeyHash != VKEY_HASH) revert InvalidVkeyHash();

        uint256 root = uint256(_unsafeCalldataBytesAccess(proof, ROOT_OFFSET));
        ROOT_VALIDATOR.requireValidRoot(root);

        uint256 numClaims = uint256(_unsafeCalldataBytesAccess(proof, NUM_CLAIMS_OFFSET));
        if (numClaims > 1 << LOG_MAX_NUM_CLAIMS) revert InvalidNumberOfClaims();

        bytes32 claimsRoot = _unsafeCalldataBytesAccess(proof, CLAIMS_ROOT_HI_OFFSET) << 128
            | _unsafeCalldataBytesAccess(proof, CLAIMS_ROOT_LO_OFFSET);

        // Verify SNARK
        (bool success,) = VERIFIER_ADDRESS.call(proof);
        if (!success) revert InvalidProof();

        validClaimsRoots[root][claimsRoot] = true;
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

    /// @dev Loads an entire word of calldata from the specified index.
    /// @param array The array to access
    function _unsafeCalldataBytesAccess(bytes calldata array, uint256 index) internal pure returns (bytes32 out) {
        /// @solidity memory-safe-assembly
        assembly {
            out := calldataload(add(array.offset, index))
        }
    }

    /// @dev Access a calldata bytes32 array without the overhead of an out of
    /// bounds check. Should only be used when `index` is known to be within
    /// bounds.
    /// @param array The array to access
    /// @param index The index to access
    /// @return out The value at the given index
    function _unsafeCalldataArrayAccess(bytes32[] calldata array, uint256 index) internal pure returns (bytes32 out) {
        /// @solidity memory-safe-assembly
        assembly {
            out := calldataload(add(array.offset, shl(5, index)))
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
