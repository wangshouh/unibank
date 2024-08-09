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
    }

    function test_readMetadata() public {
        assertEq(pToken.name(), "Proxy Token");
        assertEq(pToken.symbol(), "PT");
        assertEq(pToken.decimals(), 18);
    }

}
