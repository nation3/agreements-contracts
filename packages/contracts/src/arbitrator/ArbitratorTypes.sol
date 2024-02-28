// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

/// @dev Data estructure to configure contract deposits.
struct DepositConfig {
    /// @dev Address of the ERC20 token used for deposits.
    address token;
    /// @dev Amount of tokens to deposit.
    uint256 amount;
    /// @dev Address recipient of the deposit.
    address recipient;
}

/// @dev Posible status for a resolution.
enum ResolutionStatus {
    Idle,
    Submitted,
    Appealed,
    Endorsed,
    Executed
}

struct Resolution {
    /// @dev Status of the resolution.
    ResolutionStatus status;
    /// @dev Encoding of the settlement.
    bytes32 settlement;
    /// @dev URI of the metadata of the resolution.
    string metadataURI;
    /// @dev Timestamp from which the resolution is executable.
    uint256 unlockTime;
}
