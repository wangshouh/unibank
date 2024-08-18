// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IProxyToken {
    function withdrawUnderlyingToken(address receiver, uint256 amount) external;
}
