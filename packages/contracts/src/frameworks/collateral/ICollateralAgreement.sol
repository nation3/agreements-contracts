// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

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
        address token; // no hace falta guardarlo, pero se puede verificar que sea el mismo en cada operacion
        uint256 deposit; // la cantidad que postean todas las partes como deposito
        uint256 balance;
        // address disputedBy;
        /// @dev Status of the agreement.
        bytes32 status;
        uint256 numParties;
        mapping(address => Party) parties;
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
}
