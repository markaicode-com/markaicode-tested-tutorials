// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IChronicle} from "chronicle-std/IChronicle.sol";
import {Toll} from "chronicle-std/toll/Toll.sol";

/// TEST MOCK ONLY: uses Chronicle's real Toll (whitelist) contract, with a settable value.
contract MockChronicle is IChronicle, Toll {
    address public owner = msg.sender;
    uint256 internal val;
    uint256 internal updatedAt;

    function toll_auth() internal view override { require(msg.sender == owner, "not owner"); }
    function set(uint256 v, uint256 ts) external { require(msg.sender == owner); val = v; updatedAt = ts; }

    function wat() external pure returns (bytes32) { return "ETH/USD"; }
    function read() external view toll returns (uint256) { require(val != 0); return val; }
    function readWithAge() external view toll returns (uint256, uint256) { require(val != 0); return (val, updatedAt); }
    function tryRead() external view toll returns (bool, uint256) { return (val != 0, val); }
    function tryReadWithAge() external view toll returns (bool, uint256, uint256) { return (val != 0, val, updatedAt); }
}
