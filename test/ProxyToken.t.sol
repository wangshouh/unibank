// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ProxyToken} from "../src/ProxyToken.sol";
import {MockERC20} from "./mock/MockERC20.sol";

contract ProxyTokenTest is Test {
    ProxyToken public pToken;
    MockERC20 public token;

    function setUp() public {
        token = new MockERC20("Token", "TKN");

        pToken = new ProxyToken("Proxy Token", "PT", token);
        pToken.initRouterAddress(address(this));
    }

    function test_dupInit() public {
        vm.expectRevert();
        pToken.initRouterAddress(address(1));
    }

    function test_readMetadata() public view {
        assertEq(pToken.name(), "Proxy Token");
        assertEq(pToken.symbol(), "PT");
        assertEq(pToken.decimals(), 18);
    }

    function test_wrap() public {
        token.mint(address(this), 10 ether);
        token.approve(address(pToken), 100 ether);

        pToken.depositFor(address(this), 5 ether);
        assertEq(pToken.balanceOf(address(this)), 5 ether);
    }

    function _deposit(uint256 amount) internal {
        token.mint(address(this), amount);
        token.approve(address(pToken), type(uint256).max);

        pToken.depositFor(address(this), amount);
    }

    function test_unwrap() public {
        _deposit(5 ether);
        pToken.withdrawTo(address(1), 1 ether);
        assertEq(token.balanceOf(address(pToken)), 4 ether);
        assertEq(token.balanceOf(address(1)), 1 ether);
    }

    function test_withdrawUnderlyingToken() public {
        _deposit(5 ether);
        uint256 beforeWithdrawBalance = token.balanceOf(address(this));
        pToken.withdrawUnderlyingToken(address(this), 1 ether);
        uint256 afterWithdrawBalance = token.balanceOf(address(this));
        assertEq(afterWithdrawBalance - beforeWithdrawBalance, 1 ether);
    }

    function test_withdrawUnderlyingTokenNotOwner() public {
        vm.prank(address(1));
        vm.expectRevert("NOT_ROUTER");
        pToken.withdrawUnderlyingToken(address(1), 1 ether);
        vm.stopPrank();
    }

    function test_getUnderlyingTokenAndWithdraw() public {
        _deposit(5 ether);
        pToken.withdrawUnderlyingToken(address(this), 1 ether);
        pToken.withdrawTo(address(this), 4 ether);
        assertEq(token.balanceOf(address(this)), 5 ether);
    }
}
