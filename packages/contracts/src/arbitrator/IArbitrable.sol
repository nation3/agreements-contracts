// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

/// @notice Minimal interface for arbitrable contracts.
/// @dev Implementers must write the logic to raise and settle disputes.
interface IArbitrable {
    error NotArbitrator();
    error InvalidSettlement();

    /// @notice Address capable of settling disputes.
    function arbitrator() external view returns (address);

    /// @notice Settles the dispute `id` with the provided settlement.
    /// @param id Id of the dispute to settle.
    /// @param settlement ABI-encoded settlement configuration. Varies by agreement kind.
    function settle(bytes32 id, bytes calldata settlement) external;

    /// @notice Checks whether an address is capable of appealing
    /// @param id of the agreement/dispute to settle
    /// @param user Address to check
    function canAppeal(bytes32 id, address user) external view returns (bool);
}
