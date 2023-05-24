// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import { ISignatureTransfer } from "permit2/src/interfaces/ISignatureTransfer.sol";
import { IArbitrable } from "../interfaces/IArbitrable.sol";

interface IAgreementFramework is IArbitrable {
    error PartyNotJoined();
    error AgreementNotOngoing();
    error InvalidCollateral();
    error InvalidPartyStatus();
    error AgreementNotFinalized();

    error InvalidPermit2();

    /// @dev Raised when a new agreement is created.
    /// @param id Id of the new created agreement.
    /// @param termsHash Hash of the detailed terms of the agreement.
    /// @param token ERC20 token address to use in the agreement.
    event AgreementCreated(bytes32 indexed id, bytes32 termsHash, address token);

    /// @dev Raised when a new party joins an agreement.
    /// @param id Id of the agreement joined.
    /// @param party Address of the joined party.
    /// @param collateral Collateral of the joined party.
    event AgreementJoined(bytes32 indexed id, address indexed party, uint256 collateral);

    /// @dev Raised when an existing party of an agreement updates its position.
    /// @param id Id of the agreement updated.
    /// @param party Address of the party updated.
    /// @param status New status of the position.
    event AgreementPartyUpdated(bytes32 indexed id, address indexed party, bytes32 status);

    /// @dev Raised when an agreement is finalized.
    /// @param id Id of the agreement finalized.
    event AgreementFinalized(bytes32 indexed id);

    /// @dev Raised when an agreement is in dispute.
    /// @param id Id of the agreement in dispute.
    /// @param party Address of the party that raises the dispute.
    event AgreementDisputed(bytes32 indexed id, address indexed party);

    /// @notice Signal the will of the caller to finalize an agreement.
    /// @param id Id of the agreement to settle.
    // function finalizeAgreement(bytes32 id) external;

    /// @notice Raise a dispute over an agreement.
    /// @param id Id of the agreement to dispute.
    function disputeAgreement(bytes32 id) external;

    // TODO: check if this is needed
    /// @notice Withdraw your position from the agreement.
    /// @param id Id of the agreement to withdraw from.
    // function withdrawFromAgreement(bytes32 id, uint8 partyIndex) external;
}
