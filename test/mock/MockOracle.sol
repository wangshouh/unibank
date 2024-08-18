// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IOracle} from "src/interfaces/IOracle.sol";

contract MockOracle is IOracle {
    mapping(address base => mapping(address quote => uint256 price)) public prices;

    function getQuote(uint256 inAmount, address base, address quote) external view returns (uint256 outAmount) {
        outAmount = inAmount * prices[base][quote] / 1 ether;
    }

    function setPrice(address base, address quote, uint256 price) external {
        prices[base][quote] = price;
    }
}
