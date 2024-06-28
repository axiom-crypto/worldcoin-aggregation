// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract WLDMock is ERC20 {
    constructor(uint256 initialSupply) ERC20("WLDMock", "WLDM") {
        _mint(msg.sender, initialSupply);
    }
}
