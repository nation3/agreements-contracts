// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import { ISignatureTransfer } from "permit2/src/interfaces/ISignatureTransfer.sol";

interface ICollateralAgreement {
    error InvalidPositionOrSignaturesLength();
    error NotPartySigner();
    error NotPartOfAgreement();
    error InvalidPartySetupLength();

    struct AgreementSetup {
        bytes32 termsHash;
        address token;
        bytes32 salt;
        string metadataURI;
        PartySetup[] parties;
    }

    struct PartySetup {
        address signer;
        uint256 collateral;
        // bytes32 status;
    }

    struct Party {
        //address signer;
        uint256 collateral;
        // Encoding status
        // 0 -> Idle
        // 1 -> Joined
        // 2 -> Finalized
        // 3 -> Withdrawn
        // 4 -> Disputed
        bytes32 status;
        // Status??
    }

    // THis might not be needed
    struct PartyUpdate {
        PartySetup partyUpdate;
        bytes32 status;
    }

    struct Agreement {
        bytes32 termsHash;
        address token;
        uint256 deposit;
        uint256 totalCollateral;
        /// @dev Status of the agreement.
        bytes32 status;
        uint256 numParties;
        mapping(address => Party) parties;
    }

    struct AgreementData {
        bytes32 termsHash;
        address token;
        uint256 deposit;
        uint256 totalCollateral;
        bytes32 status;
        uint256 numParties;
    }

    struct PartyPermit {
        bytes signature;
        uint256 nonce;
        uint256 deadline;
    }

    // Unused struct for now
    struct AgreementPermit {
        AgreementSetup agreement;
        uint256 nonce;
        uint256 deadline;
    }

    struct Permit2SignatureTransfer {
        ISignatureTransfer.PermitBatchTransferFrom transferPermit;
        bytes transferSignature;
    }
}
