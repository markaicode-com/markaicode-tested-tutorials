// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

/// Reads a Pyth price and refuses to use it if it is stale, too uncertain, or not positive.
contract SafePriceReader {
    IPyth public immutable pyth;
    bytes32 public immutable feedId;

    uint256 public constant MAX_AGE = 60;       // seconds
    uint256 public constant MAX_CONF_BPS = 100; // confidence must be within 1% of the price

    error NonPositivePrice(int64 price);
    error PriceTooUncertain(int64 price, uint64 conf);

    constructor(address pythAddress, bytes32 priceFeedId) {
        pyth = IPyth(pythAddress);
        feedId = priceFeedId;
    }

    /// Push the latest update (fetched off-chain) and read the price in one transaction.
    function updateAndRead(bytes[] calldata updateData) external payable returns (int64 price, int32 expo) {
        uint256 fee = pyth.getUpdateFee(updateData);
        pyth.updatePriceFeeds{value: fee}(updateData);
        return read();
    }

    function read() public view returns (int64 price, int32 expo) {
        // Reverts with StalePrice() if the price is older than MAX_AGE.
        PythStructs.Price memory p = pyth.getPriceNoOlderThan(feedId, MAX_AGE);

        if (p.price <= 0) revert NonPositivePrice(p.price);

        // conf / price > 1%  ->  too uncertain to use
        if (uint256(p.conf) * 10_000 > uint256(uint64(p.price)) * MAX_CONF_BPS) {
            revert PriceTooUncertain(p.price, p.conf);
        }
        return (p.price, p.expo);
    }
}
