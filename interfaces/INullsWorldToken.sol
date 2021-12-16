// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface INullsWorldToken {

    function incrDayScore(address player, uint score, uint8 _type, uint8 index) external;

    function decimals() external view returns (uint8);
}