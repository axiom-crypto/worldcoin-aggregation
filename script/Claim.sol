// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {WorldcoinAggregationV2} from "../src/WorldcoinAggregationV2.sol";

contract Claim is Script {
    function run() public {
        vm.startBroadcast(); // Start broadcasting transactions

        WorldcoinAggregationV2 clientV2 = WorldcoinAggregationV2(
            0x3f88B9dc416CeADc36092673097ba456Ba878cfB
        );

        uint256 grantId = 30;
        uint256 root = 12439333144543028190433995054436939846410560778857819700795779720142743070295;
        address receiver = address(0xff9db18c23be01D48DCF1fE182f4807055ae8cA2);
        bytes32 nullifierHash = 0x2f147f560ba31a9e7ea8aa7bd36b477fb3dfb2784ff2fef7b69442918000d8ac;
        bytes32[] memory leaves = new bytes32[](4);

        leaves[0] = bytes32(
            0x55d05ad66b187a7533750526f6386d98ff0859d326ea4f1a2c846def63390990
        );
        leaves[1] = bytes32(
            0x4b4efd86a2cec7174648fca755d3b9caf672051f139e1b37846d357f29e0d889
        );
        leaves[2] = bytes32(
            0x2a3c055e5aad1f95e094e401d23a52dd4975291cc3ecbaef3a11c98dfdef94b8
        );
        leaves[3] = bytes32(
            0xebfb29350462bf97adfa61b387536ca750b8f5fc13c9221123f5ca41df8b92d1
        );

        bytes32 isLeftBytes = 0x0000000000000000000000000000000000000000000000000000000000000000;

        clientV2.claim(
            grantId,
            root,
            receiver,
            nullifierHash,
            leaves,
            isLeftBytes
        );

        vm.stopBroadcast();
    }
}
