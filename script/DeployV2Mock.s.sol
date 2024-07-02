// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "../src/mocks/GrantMock.sol";
import "../src/mocks/RootValidatorMock.sol";
import "../src/mocks/WLDMock.sol";

import {WorldcoinAggregationV2} from "../src/WorldcoinAggregationV2.sol";

contract DeployV1Mock is Script {
    function run() external {
        vm.startBroadcast();

        // 100mil supply
        // WLDMock wldMock = new WLDMock(100_000_000 * 10 ** 18);

        // RootValidatorMock rootValidatorMock = new RootValidatorMock();

        // GrantMock grantMock = new GrantMock();

        address queryAddress = 0x9C9CF878f9Ba4422BDD73B55554F0A796411D5ed;

        uint64 sourceChainId = 11155111;
        bytes32 querySchema = 0x87752627efc44b2115fa241910c349c817e36dd52551b056a6d8fbe60acef88e;
        bytes32 vKeyHash = 0x46e72119ce99272ddff09e0780b472fdc612ca799c245eea223b27e57a5f9cec;
        uint256 logMaxNumClaims = 16;

        address wldToken = 0xe93D97b0Bd30bD61a9D02B0A471DbB329D5d1fd8;
        address rootValidator = 0x9c06c3F1deecb530857127009EBE7d112ecd0E3F;
        address grant = 0x5d1F6aDfff773A2146f1f3c947Ddad1945103DaC;

        new WorldcoinAggregationV2(
            queryAddress,
            sourceChainId,
            querySchema,
            vKeyHash,
            logMaxNumClaims,
            wldToken,
            rootValidator,
            grant
        );

        vm.stopBroadcast();
    }
}
