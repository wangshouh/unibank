// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20Wrapper} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Wrapper.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract ProxyToken is ERC20Wrapper {
    bool internal _initRouter;
    address public moduleRouter;

    constructor(string memory name_, string memory symbol_, IERC20Metadata underlyingToken)
        ERC20Wrapper(underlyingToken)
        ERC20(name_, symbol_)
    {}

    function initRouterAddress(address _router) external {
        require(!_initRouter, "Init");
        moduleRouter = _router;
        _initRouter = true;
    }

    function withdrawUnderlyingToken(address receiver, uint256 amount) public {
        require(_msgSender() == moduleRouter, "NOT_ROUTER");
        underlying().transfer(receiver, amount);
    }
}
