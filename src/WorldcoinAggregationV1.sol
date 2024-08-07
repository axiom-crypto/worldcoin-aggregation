// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { IERC20 } from "./interfaces/IERC20.sol";
import { IRootValidator } from "./interfaces/IRootValidator.sol";
import { IGrant } from "./interfaces/IGrant.sol";

/// @notice This version of the aggregation contract automatically transfers the
/// grant amount to each of the users in the batch in the same tx as the
/// verification. From a UX perspective, this requires no action on the part of
/// the user to receive the grant.
///
/// @dev If there is not enough WLD balance in the contract to service the
/// entire batch being verified, the entire batch will be reverted.
contract WorldcoinAggregationV1 {
    /// @dev The verification key hash of the Groth16 circuit.
    bytes32 public immutable VKEY_HASH;

    /// @dev The maximum number of claims that can be made in a single call.
    uint256 public immutable MAX_NUM_CLAIMS;

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

    /// @dev Whether a nullifier hash has been used already. Used to prevent double-signaling
    mapping(uint256 nullifierHash => bool) public nullifierHashes;

    /// @notice Emitted when a grant is successfully claimed
    /// @param grantId The grant ID
    /// @param receiver The address that received the tokens
    event GrantClaimed(uint256 indexed grantId, address indexed receiver);

    /// @dev Only the prover can call
    error OnlyProver();

    /// @dev `MAX_NUM_CLAIMS` must be a power of two
    error InvalidMaxNumClaims();

    /// @dev SNARK verification failed
    error InvalidProof();

    /// @dev `numClaims` must be less than or equal to `MAX_NUM_CLAIMS`
    error TooManyClaims();

    /// @dev Insufficient balance WLD tokens to fulfill the claim(s)
    error InsufficientBalance();

    /// @dev The verification key of the query must match the contract's
    error InvalidVkeyHash();

    /// @dev Axiom result array must have `4 + 2 * MAX_NUM_CLAIMS` items.
    error InvalidNumberOfResults();

    modifier onlyProver() {
        if (PROVER != address(0) && msg.sender != PROVER) revert OnlyProver();
        _;
    }

    /// @notice Construct a new WorldcoinAggregationV1 contract.
    /// @param  vkeyHash The verification key hash of the Groth16 circuit.
    /// @param  maxNumClaims The number of claims that can be made in a single call.
    constructor(
        bytes32 vkeyHash,
        uint256 maxNumClaims,
        address wldToken,
        address rootValidator,
        address grant,
        address verifierAddress,
        address prover
    ) {
        // `maxNumClaims` must be a power of two
        if (maxNumClaims == 0 || maxNumClaims & (maxNumClaims - 1) != 0) revert InvalidMaxNumClaims();

        VKEY_HASH = vkeyHash;
        MAX_NUM_CLAIMS = maxNumClaims;
        WLD = IERC20(wldToken);
        ROOT_VALIDATOR = IRootValidator(rootValidator);
        GRANT = IGrant(grant);
        VERIFIER_ADDRESS = verifierAddress;
        PROVER = prover;
    }

    function distributeGrants(bytes calldata proof) external onlyProver {
        // Proof must have minimum `17 + 2 * MAX_NUM_CLAIMS` words.
        // We expect the proof to be structured as such:
        //
        // proof[0..12 * 32]: reserved for proof verification data used with the
        // pairing precompile
        //
        // proof[12 * 32..13 * 32]: vkeyHash Hi
        // proof[13 * 32..14 * 32]: vkeyHash Lo
        // proof[14 * 32..15 * 32]: grantId
        // proof[15 * 32..16 * 32]: root
        // proof[16 * 32..17 * 32]: numClaims
        // proof[idx] for idx in [17 * 32, 17 * 32 + numClaims): receivers
        // proof[idx] for idx in [17 * 32 + numClaims, 17 * 32 + numClaims + MAX_NUM_CLAIMS): claimedNullifierHashes
        //
        // if (proof.length < (17 + 2 * MAX_NUM_CLAIMS) * 32) revert InvalidProof();
        //
        // proof[(17 + 2 * MAX_NUM_CLAIMS) * 32)..]: Proof used in SNARK verification

        if (proof.length < (17 + (MAX_NUM_CLAIMS << 1)) << 5) revert InvalidProof();

        bytes32 vkeyHash = _unsafeCalldataAccess(proof, 12 << 5) << 128 | _unsafeCalldataAccess(proof, 13 << 5);
        if (vkeyHash != VKEY_HASH) revert InvalidVkeyHash();

        uint256 grantId = uint256(_unsafeCalldataAccess(proof, 14 << 5));
        GRANT.checkValidity(grantId);

        uint256 root = uint256(_unsafeCalldataAccess(proof, 15 << 5));
        ROOT_VALIDATOR.requireValidRoot(root);

        uint256 numClaims = uint256(_unsafeCalldataAccess(proof, 16 << 5));
        if (numClaims > MAX_NUM_CLAIMS) revert TooManyClaims();

        // If the entire claim cannot be fulfilled, we fail the entire batch
        uint256 grantAmount = GRANT.getAmount(grantId);
        if (grantAmount * numClaims > WLD.balanceOf(address(this))) revert InsufficientBalance();

        // Verify SNARK
        (bool success,) = VERIFIER_ADDRESS.call(proof);
        if (!success) revert InvalidProof();

        for (uint256 i = 0; i != numClaims;) {
            address receiver = _toAddress(_unsafeCalldataAccess(proof, (17 + i) << 5));
            uint256 claimedNullifierHash = uint256(_unsafeCalldataAccess(proof, (17 + i + MAX_NUM_CLAIMS) << 5));

            if (!nullifierHashes[claimedNullifierHash] && receiver != address(0)) {
                nullifierHashes[claimedNullifierHash] = true;

                WLD.transfer(receiver, grantAmount);

                emit GrantClaimed(grantId, receiver);
            }

            // Claimed nullifier hashes are skipped

            // forgefmt: disable-next-line
            unchecked { ++i; }
        }
    }

    /// @notice Cast a bytes32 to an address
    /// @dev Assembly cast to avoid solidity verbosity
    /// @param input The bytes32 to cast
    /// @return out The address casted from the input
    function _toAddress(bytes32 input) internal pure returns (address out) {
        /// @solidity memory-safe-assembly
        assembly {
            out := input
        }
    }

    /// @dev Loads an entire word of calldata from the specified index.
    /// @param array The array to access
    function _unsafeCalldataAccess(bytes calldata array, uint256 index) internal pure returns (bytes32 out) {
        /// @solidity memory-safe-assembly
        assembly {
            out := calldataload(add(array.offset, index))
        }
    }
}
