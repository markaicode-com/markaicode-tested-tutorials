// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@redstone-finance/evm-connector/contracts/core/RedstoneConsumerNumericBase.sol";

/// A RedStone pull-model consumer with the three things an auditor checks:
/// who may sign, how many must agree, and how fresh the data must be.
contract AuditedRedstoneConsumer is RedstoneConsumerNumericBase {
    // In production these are the data service's real signer addresses.
    address public immutable signer0;
    address public immutable signer1;
    address public immutable signer2;
    address public immutable signer3;
    address public immutable signer4;

    constructor(address[5] memory signers) {
        signer0 = signers[0];
        signer1 = signers[1];
        signer2 = signers[2];
        signer3 = signers[3];
        signer4 = signers[4];
    }

    function getUniqueSignersThreshold() public pure override returns (uint8) {
        return 3;
    }

    function getAuthorisedSignerIndex(address signer) public view override returns (uint8) {
        if (signer == signer0) return 0;
        if (signer == signer1) return 1;
        if (signer == signer2) return 2;
        if (signer == signer3) return 3;
        if (signer == signer4) return 4;
        revert SignerNotAuthorised(signer);
    }

    // validateTimestamp() is inherited: data older than 3 minutes or more than
    // 1 minute in the future is rejected (RedstoneDefaultsLib).

    function getEthPrice() external view returns (uint256) {
        return getOracleNumericValueFromTxMsg(bytes32("ETH"));
    }
}
