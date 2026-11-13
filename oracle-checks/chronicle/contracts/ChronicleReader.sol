// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IChronicle} from "chronicle-std/IChronicle.sol";

/// Reads a Chronicle oracle safely. Note: this contract must be whitelisted
/// ("kissed") on the oracle first, or every read reverts with NotTolled.
contract ChronicleReader {
    IChronicle public immutable chronicle;
    uint256 public constant MAX_AGE = 1 hours;

    error OracleHasNoValue();
    error StaleChroniclePrice(uint256 lastUpdate, uint256 nowTs);

    constructor(address oracle) {
        chronicle = IChronicle(oracle);
    }

    /// Returns the price with 18 decimals.
    function price() external view returns (uint256) {
        (bool ok, uint256 value, uint256 age) = chronicle.tryReadWithAge();
        if (!ok) revert OracleHasNoValue();
        // "age" is the Unix timestamp of the last update, not a number of seconds.
        if (block.timestamp - age > MAX_AGE) revert StaleChroniclePrice(age, block.timestamp);
        return value;
    }
}
