// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";

string constant DEPLOYED_ADDRESS_FILE = "script/config/deployed.json";
string constant QUERY_SCHEMA_FILE = "script/config/querySchema.json";

abstract contract AggregationDeployBase is Script {
    function _getDeployedAddresses()
        internal
        view
        returns (address queryAddress, address wldToken, address rootValidator, address grant)
    {
        string memory deployedAddressesFile = vm.readFile(DEPLOYED_ADDRESS_FILE);
        queryAddress = abi.decode(vm.parseJson(deployedAddressesFile, ".queryAddress"), (address));
        wldToken = abi.decode(vm.parseJson(deployedAddressesFile, ".wldToken"), (address));
        rootValidator = abi.decode(vm.parseJson(deployedAddressesFile, ".rootValidator"), (address));
        grant = abi.decode(vm.parseJson(deployedAddressesFile, ".grant"), (address));
    }

    function _getQuerySchema(string memory version, uint256 maxNumClaims) internal view returns (bytes32 querySchema) {
        string memory querySchemaFile = vm.readFile(QUERY_SCHEMA_FILE);
        string memory path =
            string.concat(string.concat(".", version), string.concat(".", Strings.toString(maxNumClaims)));
        querySchema = abi.decode(vm.parseJson(querySchemaFile, path), (bytes32));
    }
}
