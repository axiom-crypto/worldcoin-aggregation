// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { WorldcoinAggregationV2 } from "../src/WorldcoinAggregationV2.sol";
import { AggregationDeployBase } from "./AggregationDeployBase.s.sol";

import { IERC20 } from "../src/interfaces/IERC20.sol";

/// Deploy the v2 aggregation contract with mocked WLD, RootValidator and Grant contract.
/// For the WLD token, the transfer function is expected to only return true or revert.
/// WorldcoinAggregationV2 is not compatible with ERC20 tokens that return false on transfer failure.
contract DeployAggregationV2 is AggregationDeployBase {
    function run(uint256 logMaxNumClaims) external {
        vm.startBroadcast();

        bytes32 vKeyHash = 0x46e72119ce99272ddff09e0780b472fdc612ca799c245eea223b27e57a5f9cec;

        uint256 maxNumClaims = 2 ** logMaxNumClaims;

        (address wldToken, address rootValidator, address grant) = _getDeployedAddresses();

        address verifier = _deployVerifier("v2", maxNumClaims);

        WorldcoinAggregationV2 worldcoinAggV2 =
             new WorldcoinAggregationV2(vKeyHash, logMaxNumClaims, wldToken, rootValidator, grant, verifier, address(0));

        IERC20 wldTokenContract = IERC20(wldToken);
        uint256 transferAmount = 100_000 * 10 ** 18;
        wldTokenContract.transfer(address(worldcoinAggV2), transferAmount);

        vm.stopBroadcast();
    }
}
