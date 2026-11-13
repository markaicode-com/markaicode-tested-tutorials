// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uma/core/contracts/optimistic-oracle-v3/interfaces/OptimisticOracleV3Interface.sol";

/// Asks UMA's Optimistic Oracle V3 to accept a plain-English claim.
/// If nobody disputes it within LIVENESS, it's treated as true.
contract OptimisticClaim {
    using SafeERC20 for IERC20;

    OptimisticOracleV3Interface public immutable oo;
    IERC20 public immutable bondToken;
    uint64 public constant LIVENESS = 2 hours;

    constructor(address _oo, address _bondToken) {
        oo = OptimisticOracleV3Interface(_oo);
        bondToken = IERC20(_bondToken);
    }

    /// The caller posts the bond; it goes back to them if the claim survives.
    function assertClaim(string calldata claim) external returns (bytes32 assertionId) {
        uint256 bond = oo.getMinimumBond(address(bondToken));
        bondToken.safeTransferFrom(msg.sender, address(this), bond);
        bondToken.safeApprove(address(oo), bond);
        assertionId = oo.assertTruth(
            bytes(claim),
            msg.sender,          // asserter: receives the bond back (or loses it)
            address(0),          // no callback contract
            address(0),          // no escalation manager: disputes go to UMA's DVM
            LIVENESS,
            bondToken,
            bond,
            oo.defaultIdentifier(),
            bytes32(0)
        );
    }

    /// Reverts until the assertion has been settled.
    function isTrue(bytes32 assertionId) external view returns (bool) {
        return oo.getAssertionResult(assertionId);
    }
}
