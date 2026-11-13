// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "usingtellorlayer/contracts/interfaces/ITellorDataBridge.sol";

/// Accepts a Tellor Layer price only after the bridge has verified the validators'
/// signatures AND the data passes our own checks.
contract SafeTellorPriceConsumer {
    ITellorDataBridge public immutable bridge;
    bytes32 public immutable queryId;

    uint256 public price;            // value as reported (e.g. 18 decimals for SpotPrice)
    uint256 public priceTimestamp;   // report time, in MILLISECONDS (Tellor Layer uses ms)

    error WrongQueryId();
    error AttestationTooOld();
    error ReportTooRecent();
    error NotEnoughReporterPower();
    error NotNewerThanStored();

    constructor(address _bridge, bytes32 _queryId) {
        bridge = ITellorDataBridge(_bridge);
        queryId = _queryId;
    }

    function updatePrice(
        OracleAttestationData calldata _attestData,
        Validator[] calldata _currentValidatorSet,
        Signature[] calldata _sigs
    ) external {
        // 1. Authenticate first: reverts unless enough validator power signed this exact data.
        bridge.verifyOracleData(_attestData, _currentValidatorSet, _sigs);

        // 2. Is it the feed we asked for?
        if (_attestData.queryId != queryId) revert WrongQueryId();

        // 3. Was it attested recently? (timestamps are in ms)
        if (block.timestamp - (_attestData.attestationTimestamp / 1000) > 10 minutes) revert AttestationTooOld();

        // 4. Did the report sit unchallenged long enough to be disputed? (12 hours)
        if (_attestData.attestationTimestamp - _attestData.report.timestamp < 12 hours * 1000) revert ReportTooRecent();

        // 5. Enough reporter power behind the value?
        if (_attestData.report.aggregatePower < bridge.powerThreshold()) revert NotEnoughReporterPower();

        // 6. Never go backwards (blocks replaying an older attestation).
        if (_attestData.report.timestamp <= priceTimestamp) revert NotNewerThanStored();

        price = abi.decode(_attestData.report.value, (uint256));
        priceTimestamp = _attestData.report.timestamp;
    }
}
