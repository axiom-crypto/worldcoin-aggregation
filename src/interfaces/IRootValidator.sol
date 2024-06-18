// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Interface for contract that validates World ID roots.
/// @dev This will be the Identity Manager contract on Ethereum Mainnet and the
/// Bridged World ID contract on all other chains.
interface IRootValidator {
    /// @notice Validates the provided root.
    /// @dev Function will revert internally. Use try/catch or low-level call to
    /// handle failure.
    ///
    /// @param root The root to validate.
    function requireValidRoot(uint256 root) external view;
}
