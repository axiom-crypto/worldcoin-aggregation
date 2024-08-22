// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import { WorldcoinAggregationV2 } from "../src/WorldcoinAggregationV2.sol";
import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";

string constant CLAIM_FILE = "script/config/claim.json";
string constant V2_CLIENT = "script/config/v2client.json";

contract ClaimScript is Script {
    // Use string for grantId and root since the merkleSisterNode script is in typescript
    // and it can't output bigint without quote
    // It looks like foundry has some bugs in encoding parsed json and the fields need to
    // be in alphabetic order
    struct Claim {
        string grantId;
        bytes32 isLeftBytes;
        bytes32 nullifierHash;
        address receiver;
        string root;
        bytes32[] sisterNodes;
    }

    function run() public {
        vm.startBroadcast();

        string memory claimFile = vm.readFile(CLAIM_FILE);
        bytes memory data = vm.parseJson(claimFile);
        Claim memory claim = abi.decode(data, (Claim));

        uint256 logMaxNumClaims = claim.sisterNodes.length;
        uint256 maxNumClaims = 2 ** logMaxNumClaims;

        string memory v2ClientFile = vm.readFile(V2_CLIENT);
        string memory prefix = string.concat(string.concat(".", Strings.toString(maxNumClaims)));

        address v2clientAddr = abi.decode(vm.parseJson(v2ClientFile, prefix), (address));

        uint256 grantId = stringToUint(claim.grantId);
        uint256 root = stringToUint(claim.root);

        WorldcoinAggregationV2 clientV2 = WorldcoinAggregationV2(v2clientAddr);

        clientV2.claim(grantId, root, claim.receiver, claim.nullifierHash, claim.sisterNodes, claim.isLeftBytes);

        vm.stopBroadcast();
    }

    function stringToUint(string memory s) public pure returns (uint256) {
        bytes memory b = bytes(s);
        uint256 result = 0;
        for (uint256 i = 0; i < b.length; i++) {
            uint256 c = uint256(uint8(b[i]));
            result = result * 10 + (c - 48);
        }
        return result;
    }
}
