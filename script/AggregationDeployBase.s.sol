// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

string constant DEPLOYED_ADDRESS_FILE = "script/config/deployed.json";

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
}
