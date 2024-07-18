// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { WorldcoinAggregationV1 } from "../src/WorldcoinAggregationV1.sol";
import { AggregationDeployBase } from "./AggregationDeployBase.s.sol";

import { IERC20 } from "../src/interfaces/IERC20.sol";

/// Deploy the v1 aggregation contract with mocked WLD, RootValidator and Grant contract.
/// For the WLD token, the transfer function is expected to only return true or revert.
/// WorldcoinAggregationV1 is not compatible with ERC20 tokens that return false on transfer failure.
contract DeployAggregationV1 is AggregationDeployBase {
    function run(uint256 maxNumClaims) external {
        vm.startBroadcast();

        uint64 sourceChainId = 11_155_111;
        bytes32 vKeyHash = 0x46e72119ce99272ddff09e0780b472fdc612ca799c245eea223b27e57a5f9cec;

        bytes32 querySchema = _getQuerySchema("v1", maxNumClaims);

        (address queryAddress, address wldToken, address rootValidator, address grant) = _getDeployedAddresses();

        WorldcoinAggregationV1 worldcoinAggV1 = new WorldcoinAggregationV1(
            queryAddress, sourceChainId, querySchema, vKeyHash, maxNumClaims, wldToken, rootValidator, grant
        );

        IERC20 wldTokenContract = IERC20(wldToken);
        uint256 transferAmount = 1000 * 10 ** 18;
        wldTokenContract.transfer(address(worldcoinAggV1), transferAmount);

        vm.stopBroadcast();
    }
}
