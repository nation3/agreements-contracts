// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import { ICollateralAgreement } from "./ICollateralAgreement.sol";

library CollateralHash {
    bytes32 public constant AGREEMENT_SETUP_TYPEHASH =
        keccak256(
            "AgreementSetup(bytes32 termsHash,address token,bytes32 salt,string metadataURI,PartySetup[] parties)PartySetup(address signer,uint256 collateral)"
        );

    bytes32 public constant PARTY_SETUP_TYPEHASH =
        keccak256("PartySetup(address signer,uint256 collateral)");

    bytes32 public constant JOIN_PERMIT_TYPEHASH =
        keccak256(
            "AgreementPermit(AgreementSetup agreement,uint256 nonce,uint256 deadline)AgreementSetup(bytes32 termsHash,address token,bytes32 salt,string metadataURI,PartySetup[] parties)PartySetup(address signer,uint256 collateral)"
        );
    bytes32 public constant UPDATE_PARTY_TYPEHASH =
        keccak256(
            "PartyUpdate(PartySetup partyUpdate,bytes32 status, uint256 nonce,uint256 deadline)PartySetup(address signer,uint256 collateral)"
        );

    function hashWithAgreement(
        ICollateralAgreement.PartyPermit memory joinPermit,
        bytes32 agreement
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(JOIN_PERMIT_TYPEHASH, agreement, joinPermit.nonce, joinPermit.deadline)
            );
    }

    function hashWithNonceAndStatus(
        ICollateralAgreement.PartySetup memory partySetup,
        ICollateralAgreement.PartyPermit memory partyPermit,
        bytes32 status
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    UPDATE_PARTY_TYPEHASH,
                    partySetup,
                    status,
                    partyPermit.nonce,
                    partyPermit.deadline
                )
            );
    }

    // TODO: We might not need this anymore
    function hash(ICollateralAgreement.PartySetup memory party) internal pure returns (bytes32) {
        return _hashParty(party);
    }

    function hash(
        ICollateralAgreement.AgreementSetup calldata agreementSetup
    ) internal pure returns (bytes32) {
        uint256 numParties = agreementSetup.parties.length;
        bytes32[] memory partyHashes = new bytes32[](numParties);

        for (uint256 i = 0; i < numParties; ++i) {
            partyHashes[i] = _hashParty(agreementSetup.parties[i]);
        }

        return
            keccak256(
                abi.encode(
                    AGREEMENT_SETUP_TYPEHASH,
                    agreementSetup.termsHash,
                    agreementSetup.token,
                    agreementSetup.salt,
                    keccak256(bytes(agreementSetup.metadataURI)),
                    keccak256(abi.encodePacked(partyHashes))
                )
            );
    }

    function _hashParty(
        ICollateralAgreement.PartySetup memory party
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(PARTY_SETUP_TYPEHASH, party.signer, party.collateral));
    }
}
