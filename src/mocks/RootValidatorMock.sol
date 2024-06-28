// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../interfaces/IRootValidator.sol";

contract RootValidatorMock is IRootValidator {
    function requireValidRoot(uint256 root) external view override {
        // This function intentionally does nothing and will never revert,
        // mocking the behavior of always validating the root successfully.
    }
}
