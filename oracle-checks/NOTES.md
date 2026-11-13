# Oracle integration checks (Pyth, RedStone, Tellor, Chronicle, UMA, Band, API3)

Companion code for these Markaicode guides:
- https://markaicode.com/pyth-network-v3-data-quality-guide/
- https://markaicode.com/audit-redstone-data-signatures/
- https://markaicode.com/tellor-oracle-guide/
- https://markaicode.com/chronicle-oracle-guide/
- https://markaicode.com/uma-optimistic-oracle-guide/
- https://markaicode.com/vs/band-protocol-vs-api3/

## How these were run (2026-11-14)

Linux container, Node 22.22, npm 10.9. Contracts compiled with solc-js (npm `solc`) and run on an
in-process Ganache 7.9.2 chain (shanghai/london/paris hardfork) with ethers. No public network was used,
so nothing here touches real oracle deployments, real signers or real prices.

| Folder | What is real | What is simulated | Result |
|---|---|---|---|
| pyth | Pyth's official `MockPyth` + `IPyth` from @pythnetwork/pyth-sdk-solidity 4.3.1 | price updates (MockPyth.createPriceFeedUpdateData) | test-log.txt: fresh ok, >60 s StalePrice, older update silently ignored, 2% confidence rejected, negative rejected, future publishTime StalePrice, 0 fee InsufficientFee |
| redstone | RedStone's real `RedstoneConsumerNumericBase` (evm-connector 0.9.0) and signed data packages (protocol 0.9.0, mock signer keys) | signers are RedStone's public test keys, not production signers | median of 3 ok; 2 signers, unknown signer, duplicate signer, 4-min-old, 2-min-future, mixed timestamps all revert; one manipulated value ignored by the median |
| tellor | Tellor's real `TellorDataBridge` (usingtellorlayer 1.3.0), real ECDSA validator signatures | the validator set is 3 random local keys | valid accepted; replay, outsider key, 1/3 power, old attestation, report inside 12 h window, wrong queryId, seconds-instead-of-ms, low reporter power all rejected |
| chronicle | Chronicle's real `Toll` whitelist and `IChronicle` (chronicle-std @973f439) | the oracle value (test mock) | not whitelisted NotTolled; fresh ok; 2 h old rejected; no value rejected |
| uma | UMA's real `OptimisticOracleV3`, Finder, Store, IdentifierWhitelist, AddressWhitelist (@uma/core 2.62.2) | the DVM vote (UMA's own `MockOracleAncillary`) and a test ERC-20 bond token; liveness set to 7200 s by us | undisputed claim true after 2 h; disputed claim false/true per DVM; bond accounting; late dispute rejected |
| band-api3 | `IApi3ReaderProxy` from @api3/contracts 43.0.0; Band's `IStdReference` as published in Band's docs | — | compile check only (no chain test) |

## Notes and traps found
- **RedStone:** `@redstone-finance/evm-connector@1.0.0` (2026-08-31) lists `workspace:*` dependencies, so `npm install` fails. 0.9.0 installs.
- **RedStone:** the docs mention overriding `isTimestampValid`, but the contract function in 0.9.0 and 1.0.0 is `validateTimestamp`.
- **Ganache eth_call timing:** a plain `eth_call` after `evm_increaseTime` can run with a different timestamp than the last mined block. The Pyth checks therefore read the price in the same call as the update (`updateAndRead`), which is also how production code should do it.
- **UMA:** the test project needs @uma/core's Solidity sources: `npm pack @uma/core@2.62.2` and extract the tarball into `src/` (compile.js reads `src/package/contracts`). OptimisticOracleV3 pins `pragma solidity 0.8.16`.
- **Chronicle:** `chronicle-std` isn't on npm. Clone github.com/chronicleprotocol/chronicle-std into `chronicle-std/` (compile.js maps that path).
