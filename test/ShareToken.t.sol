// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ShareToken} from "../src/ShareToken.sol";
import {ProxyToken} from "../src/ProxyToken.sol";
import {ConstantInterestRateModel} from "../src/modules/InterestRateModel.sol";
import {MockERC20} from "./mock/MockERC20.sol";
import {MockOracle} from "./mock/MockOracle.sol";

contract ShareTokenTest is Test {
    ProxyToken public pToken;
    ShareToken public sToken;
    ConstantInterestRateModel public rateModel;
    MockERC20 public token;
    MockERC20 public collateralToken;
    MockOracle public oracle;

    function setUp() public {
        rateModel = new ConstantInterestRateModel(0.05e9);
        oracle = new MockOracle();
        token = new MockERC20("Token", "TKN");
        collateralToken = new MockERC20("Collateral", "C");

        pToken = new ProxyToken("Proxy Token", "PT", token);
        sToken = new ShareToken("Share Token", "ST", pToken, address(this));
        pToken.initRouterAddress(address(sToken));

        sToken.setCollateral(address(collateralToken), true);
        sToken.setInterestRateModel(address(rateModel));
        sToken.setOracle(address(oracle));

        pToken.approve(address(sToken), type(uint256).max);
        token.approve(address(pToken), type(uint256).max);
        token.approve(address(sToken), type(uint256).max);

        collateralToken.mint(address(this), 10 ether);
        collateralToken.approve(address(sToken), 100 ether);

        oracle.setPrice(address(collateralToken), address(pToken), 1.1 ether);
    }

    function _depositPT(uint256 amount) internal {
        token.mint(address(this), amount);
        pToken.depositFor(address(this), amount);
    }

    function _depositST(uint256 amount) internal {
        token.mint(address(this), amount);
        pToken.depositFor(address(this), amount);

        sToken.deposit(amount, address(this));
    }

    function test_deposit() public {
        _depositPT(10 ether);
        sToken.deposit(10 ether, address(1));

        assertEq(sToken.balanceOf(address(1)), 10 ether);
    }

    function test_withdraw() public {
        _depositPT(20 ether);
        sToken.deposit(10 ether, address(1));
        pToken.transfer(address(sToken), 10 ether);

        vm.startPrank(address(1));
        sToken.redeem(10 ether, address(1), address(1));
        vm.stopPrank();
        assertEq(pToken.balanceOf(address(1)), 20 ether - 1);
    }

    function test_setCollateral() public {
        sToken.setCollateral(address(1), true);
        assertEq(sToken.isCollateral(address(1)), true);
    }

    function test_depositCollateral() public {
        sToken.setCollateral(address(collateralToken), true);
        sToken.depositCollateral(address(1), address(collateralToken), 5 ether);
    }

    function test_borrowTooBig() public {
        vm.expectRevert("Amount too large");
        sToken.borrow(address(collateralToken), 10 ether);
    }

    function test_borrowCollateralTooSmall() public {
        _depositPT(10 ether);
        vm.expectRevert("Collateral Not Enough");
        sToken.borrow(address(collateralToken), 1 ether);
    }

    function test_borrowWithRepay() public {
        _depositPT(10 ether);

        sToken.depositCollateral(address(this), address(collateralToken), 5 ether);
        sToken.borrow(address(collateralToken), 1 ether);

        assertEq(sToken.getUserDebt(address(collateralToken), address(this)), 1 ether);

        vm.roll(block.number + 21);

        assertEq(sToken.getUserDebt(address(collateralToken), address(this)), 1 ether * 1.05e9 / 1e9);

        sToken.repay(address(this), address(collateralToken), 0.05 ether);
        assertEq(sToken.liquidityDebt(address(collateralToken), address(this)), 0.95 ether);
        assertEq(sToken.getUserDebt(address(collateralToken), address(this)), 1 ether * 1.05e9 / 1e9 - 0.05 ether);

        vm.roll(block.number + 21);
        assertEq(sToken.getUserDebt(address(collateralToken), address(this)), 1 ether * 1.05e9 / 1e9);
    }

    function test_liquidiateNot() public {
        _depositPT(10 ether);
        sToken.depositCollateral(address(this), address(collateralToken), 5 ether);
        sToken.borrow(address(collateralToken), 4 ether);
        vm.expectRevert("Not liquidable");
        sToken.liquidate(address(this), address(collateralToken));
    }

    function test_liquidate() public {
        _depositPT(10 ether);
        sToken.depositCollateral(address(this), address(collateralToken), 5 ether);
        sToken.borrow(address(collateralToken), 4 ether);

        vm.roll(block.number + 420);
        vm.startPrank(address(1));
        token.mint(address(1), 10 ether);
        token.approve(address(sToken), 100 ether);

        sToken.liquidate(address(this), address(collateralToken));
        assertEq(collateralToken.balanceOf(address(1)), 5 ether);
        assertEq(sToken.getUserDebt(address(collateralToken), address(this)), 0);
        vm.stopPrank();
    }
}
