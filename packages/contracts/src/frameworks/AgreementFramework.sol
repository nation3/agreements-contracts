// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import { IArbitrable } from "../interfaces/IArbitrable.sol";
import { IAgreementFramework } from "./IAgreementFramework.sol";
import { Owned } from "../utils/Owned.sol";

abstract contract AgreementFramework is IAgreementFramework, Owned {
    /* ====================================================================== */
    /*                       COMMON EXTENSIBLE STATUSES
    /* ====================================================================== */

    bytes32 public constant AGREEMENT_STATUS_IDLE =
        keccak256(abi.encodePacked("AGREEMENT_STATUS_IDLE"));
    bytes32 public constant AGREEMENT_STATUS_ONGOING =
        keccak256(abi.encodePacked("AGREEMENT_STATUS_ONGOING"));
    bytes32 public constant AGREEMENT_STATUS_DISPUTED =
        keccak256(abi.encodePacked("AGREEMENT_STATUS_DISPUTED"));
    bytes32 public constant AGREEMENT_STATUS_FINALIZED =
        keccak256(abi.encodePacked("AGREEMENT_STATUS_FINALIZED"));

    bytes32 public constant PARTY_STATUS_IDLE = keccak256(abi.encodePacked("PARTY_STATUS_IDLE"));
    bytes32 public constant PARTY_STATUS_JOINED =
        keccak256(abi.encodePacked("PARTY_STATUS_JOINED"));
    bytes32 public constant PARTY_STATUS_FINALIZED =
        keccak256(abi.encodePacked("PARTY_STATUS_FINALIZED"));
    bytes32 public constant PARTY_STATUS_RELEASED =
        keccak256(abi.encodePacked("PARTY_STATUS_RELEASED"));
    bytes32 public constant PARTY_STATUS_DISPUTED =
        keccak256(abi.encodePacked("PARTY_STATUS_DISPUTED"));

    /// @inheritdoc IArbitrable
    address public arbitrator;

    /// @notice Raised when the arbitration power is transferred.
    /// @param newArbitrator Address of the new arbitrator.
    event ArbitrationTransferred(address indexed newArbitrator);

    /// @notice Transfer the arbitration power of the agreement.
    /// @param newArbitrator Address of the new arbitrator.
    function transferArbitration(address newArbitrator) public virtual onlyOwner {
        arbitrator = newArbitrator;

        emit ArbitrationTransferred(newArbitrator);
    }

    /// @notice
    // function createWithAllowance() external virtual;

    /// Creates an agreement with all party signatures
    // function createWithSignatures() external virtual;

    // function partialJoinAllowance() external virtual;

    // function partialJoinSignature() external virtual;

    /// Adjusts a party position
    // function adjustParty() external virtual;
}
