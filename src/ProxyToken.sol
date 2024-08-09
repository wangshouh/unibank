// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20Wrapper} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Wrapper.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract ProxyToken is ERC20Wrapper {
    constructor(string memory name_, string memory symbol_, IERC20Metadata underlyingToken)
        ERC20Wrapper(underlyingToken)
        ERC20(name_, symbol_)
    {}
}
