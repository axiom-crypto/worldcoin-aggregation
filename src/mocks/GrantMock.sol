// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IGrant } from "../../src/interfaces/IGrant.sol";

contract GrantMock is IGrant {
    uint256 internal immutable launchDayTimestampInSeconds = 1_690_167_600; // Monday, 24 July 2023 03:00:00

    function calculateId(uint256 timestamp) external pure returns (uint256) {
        if (timestamp < launchDayTimestampInSeconds) revert InvalidGrant();

        uint256 weeksSinceLaunch = (timestamp - launchDayTimestampInSeconds) / 1 weeks;
        uint256 grantId = 15 + (weeksSinceLaunch - 3) / 2;
        // Grant 29 is a four-week grant.
        if (grantId <= 29) return grantId;
        return grantId - 1;
    }

    function getCurrentId() external view override returns (uint256) {
        return this.calculateId(block.timestamp);
    }

    function getAmount(uint256 grantId) external pure override returns (uint256) {
        // Grant 30 is a 6 WLD grant.
        if (grantId == 30) return 6 * 10 ** 18;
        return 3 * 10 ** 18;
    }

    function checkValidity(uint256 grantId) external view override {
        // This function intentionally does nothing and will never revert.
    }

    function checkReservationValidity(uint256 timestamp) external view override {
        // This function intentionally does nothing and will never revert.
    }
}
