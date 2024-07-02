// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "../src/mocks/GrantMock.sol";
import "../src/mocks/RootValidatorMock.sol";
import "../src/mocks/WLDMock.sol";

import {WorldcoinAggregationV1} from "../src/WorldcoinAggregationV1.sol";

contract DeployMock is Script {
    function run() external {
        vm.startBroadcast();

        // 100mil supply
        // WLDMock wldMock = new WLDMock(100_000_000 * 10 ** 18);

        // RootValidatorMock rootValidatorMock = new RootValidatorMock();

        // GrantMock grantMock = new GrantMock();

        address queryAddress = 0x9C9CF878f9Ba4422BDD73B55554F0A796411D5ed;
        uint64 sourceChainId = 11155111;
        bytes32 querySchema = 0xa72441820512403e5a2328a333facfbcafb0fad2cfbeb48c3c1d18771d8651d4;
        bytes32 vKeyHash = 0x46e72119ce99272ddff09e0780b472fdc612ca799c245eea223b27e57a5f9cec;
        uint256 maxNumClaims = 16;

        address wldToken = 0xe93D97b0Bd30bD61a9D02B0A471DbB329D5d1fd8;
        address rootValidator = 0x9c06c3F1deecb530857127009EBE7d112ecd0E3F;
        address grant = 0x5d1F6aDfff773A2146f1f3c947Ddad1945103DaC;

        new WorldcoinAggregationV1(
            queryAddress,
            sourceChainId,
            querySchema,
            vKeyHash,
            maxNumClaims,
            wldToken,
            rootValidator,
            grant
        );

        vm.stopBroadcast();
    }
}
