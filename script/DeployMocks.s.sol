// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "../src/mocks/GrantMock.sol";
import "../src/mocks/RootValidatorMock.sol";
import "../src/mocks/WLDMock.sol";

/// Deploy mocked Grant, RootValidator and WLD contracts
contract DeployMocks is Script {
    function run() external {
        vm.startBroadcast();

        // 100mil supply
        WLDMock wldMock = new WLDMock(100_000_000 * 10 ** 18);

        RootValidatorMock rootValidatorMock = new RootValidatorMock();

        GrantMock grantMock = new GrantMock();

        vm.stopBroadcast();
    }
}
