// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IIRM {
    function computeInterestRate(address vault, uint256 cash, uint256 borrows) external view returns (uint256);
}
