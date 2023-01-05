// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

/// @dev Thrown when the positions on a settlement don't match the ones in the dispute.
error SettlementPositionsMustMatch();
/// @dev Thrown when the total balance of a settlement don't match the one in the dispute.
error SettlementBalanceMustMatch();
