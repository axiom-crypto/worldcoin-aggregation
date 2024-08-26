// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";

import { V1Claim2Verifier } from "../src/verifiers/v1/V1Claim2Verifier.sol";
import { V1Claim16Verifier } from "../src/verifiers/v1/V1Claim16Verifier.sol";
import { V1Claim32Verifier } from "../src/verifiers/v1/V1Claim32Verifier.sol";
import { V1Claim64Verifier } from "../src/verifiers/v1/V1Claim64Verifier.sol";
import { V1Claim128Verifier } from "../src/verifiers/v1/V1Claim128Verifier.sol";
import { V1Claim256Verifier } from "../src/verifiers/v1/V1Claim256Verifier.sol";


import { V2Claim2Verifier } from "../src/verifiers/v2/V2Claim2Verifier.sol";
import { V2Claim16Verifier } from "../src/verifiers/v2/V2Claim16Verifier.sol";
import { V2Claim32Verifier } from "../src/verifiers/v2/V2Claim32Verifier.sol";
import { V2Claim64Verifier } from "../src/verifiers/v2/V2Claim64Verifier.sol";
import { V2Claim128Verifier } from "../src/verifiers/v2/V2Claim128Verifier.sol";
import { V2Claim8192Verifier } from "../src/verifiers/v2/V2Claim8192Verifier.sol";


string constant DEPLOYED_ADDRESS_FILE = "script/config/deployed.json";

abstract contract AggregationDeployBase is Script {
    function _getDeployedAddresses()
        internal
        view
        returns (address wldToken, address rootValidator, address grant)
    {
        string memory deployedAddressesFile = vm.readFile(DEPLOYED_ADDRESS_FILE);
        wldToken = abi.decode(vm.parseJson(deployedAddressesFile, ".wldToken"), (address));
        rootValidator = abi.decode(vm.parseJson(deployedAddressesFile, ".rootValidator"), (address));
        grant = abi.decode(vm.parseJson(deployedAddressesFile, ".grant"), (address));
    }

    function _deployVerifier(string memory version, uint256 maxNumClaims) internal returns (address verifier) {
        bytes32 versionHash = keccak256(abi.encodePacked(version));

        if (versionHash == keccak256(abi.encodePacked("v1"))) {
            if (maxNumClaims == 2) verifier = address(new V1Claim2Verifier());
            else if (maxNumClaims == 16) verifier = address(new V1Claim16Verifier());
            else if (maxNumClaims == 32) verifier = address(new V1Claim32Verifier());
            else if (maxNumClaims == 64) verifier = address(new V1Claim64Verifier());
            else if (maxNumClaims == 128) verifier = address(new V1Claim128Verifier());
            else if (maxNumClaims == 256) verifier = address(new V1Claim256Verifier());
            else revert("Invalid numClaims value");
        } else if (versionHash == keccak256(abi.encodePacked("v2"))) {
            if (maxNumClaims == 2) verifier = address(new V2Claim2Verifier());
            else if (maxNumClaims == 16) verifier = address(new V2Claim16Verifier());
            else if (maxNumClaims == 32) verifier = address(new V2Claim32Verifier());
            else if (maxNumClaims == 64) verifier = address(new V2Claim64Verifier());
            else if (maxNumClaims == 128) verifier = address(new V2Claim128Verifier());
            else if (maxNumClaims == 8192) verifier = address(new V2Claim8192Verifier());
            else revert("Invalid numClaims value");
        } else {
            revert("Invalid version");
        }
    }
}
