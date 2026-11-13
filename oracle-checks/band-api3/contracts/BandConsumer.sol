// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStdReference {
    struct ReferenceData {
        uint256 rate;             // base/quote rate, multiplied by 1e18
        uint256 lastUpdatedBase;  // unix time the base price was updated
        uint256 lastUpdatedQuote; // unix time the quote price was updated
    }
    function getReferenceData(string memory _base, string memory _quote) external view returns (ReferenceData memory);
}

contract BandConsumer {
    IStdReference public immutable ref;
    uint256 public constant MAX_AGE = 1 hours;

    constructor(address _ref) {
        ref = IStdReference(_ref);
    }

    /// ETH/USD with 18 decimals.
    function ethUsd() external view returns (uint256) {
        IStdReference.ReferenceData memory d = ref.getReferenceData("ETH", "USD");
        // Both legs of the pair must be fresh.
        require(block.timestamp - d.lastUpdatedBase <= MAX_AGE, "Stale base");
        require(block.timestamp - d.lastUpdatedQuote <= MAX_AGE, "Stale quote");
        return d.rate;
    }
}
