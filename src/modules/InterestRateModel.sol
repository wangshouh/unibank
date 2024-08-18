// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract ConstantInterestRateModel {
    uint256 public immutable baseRate;

    constructor(uint256 _baseRate) {
        baseRate = _baseRate;
    }

    function computeInterestRate(address, uint256, uint256) external view returns (uint256) {
        return baseRate;
    }
}
