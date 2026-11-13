// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@api3/contracts/interfaces/IApi3ReaderProxy.sol";

contract Api3Consumer {
    IApi3ReaderProxy public immutable proxy; // your dApp's Api3ReaderProxyV1 for the feed

    constructor(address _proxy) {
        proxy = IApi3ReaderProxy(_proxy);
    }

    /// Price with 18 decimals.
    function price() external view returns (uint256) {
        (int224 value, uint32 timestamp) = proxy.read();
        require(value > 0, "Non-positive price");
        // API3's docs: only use the timestamp to check the heartbeat is upheld.
        require(timestamp + 24 hours > block.timestamp, "Heartbeat missed");
        return uint256(int256(value));
    }
}
