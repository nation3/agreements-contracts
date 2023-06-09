// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import { IAllowanceTransfer } from "permit2/src/interfaces/IAllowanceTransfer.sol";
import { ISignatureTransfer } from "permit2/src/interfaces/ISignatureTransfer.sol";

// import { Permit2Lib } from "permit2/src/libraries/Permit2Lib.sol";
import { ERC20 } from "solmate/src/tokens/ERC20.sol";
import { ReentrancyGuard } from "solmate/src/utils/ReentrancyGuard.sol";
import { SafeTransferLib } from "solmate/src/utils/SafeTransferLib.sol";

import { SignatureVerification } from "permit2/src/libraries/SignatureVerification.sol";

import { CollateralHash } from "./CollateralHash.sol";

import {
    SettlementPositionsMustMatch,
    SettlementBalanceMustMatch
} from "../../interfaces/ArbitrationErrors.sol";
import { IArbitrable } from "../../interfaces/IArbitrable.sol";
import { ICollateralAgreement } from "./ICollateralAgreement.sol";

import { AgreementFramework } from "../../frameworks/AgreementFramework.sol";
import { DepositConfig } from "../../utils/interfaces/Deposits.sol";
import { Owned } from "../../utils/Owned.sol";
import { EIP712WithNonces } from "../../utils/EIP712WithNonces.sol";

/**
    Contract is still a WIP. It is not yet ready for production use.
    Funds may be lost if used on mainnet in its current form.

    Several aspects need attention:
    - Standard arbitration settlement via arbitrary calldata
    - Locked tokens
    - Audit permissions
    - Release mechanism
    - Comments and general structure
    - Agreement signature nonces / Nonce revoke mechanism
 */
contract CollateralAgreement is
    AgreementFramework,
    ReentrancyGuard,
    ICollateralAgreement,
    EIP712WithNonces
{
    using SignatureVerification for bytes;
    using SafeTransferLib for ERC20;
    // using Permit2Lib for ERC20;

    using CollateralHash for AgreementSetup;
    using CollateralHash for PartySetup;
    using CollateralHash for PartyPermit;

    /// @notice Address of the Permit2 contract deployment.
    ISignatureTransfer public immutable permit2;

    /// @notice Dispute deposits configuration.
    DepositConfig public depositConfig;

    /// @dev Agreements by id
    mapping(bytes32 => Agreement) public agreements;

    /* ====================================================================== */
    /*                                  VIEWS
    /* ====================================================================== */

    // TODO

    /* ====================================================================== */
    /*                                  SETUP
    /* ====================================================================== */

    constructor(
        ISignatureTransfer permit2_,
        address owner
    ) Owned(owner) EIP712WithNonces(keccak256("N3CollateralAgreement"), "1") {
        permit2 = permit2_;
    }

    /// @notice Set up framework params;
    /// @param arbitrator_ Address allowed to settle disputes.
    /// @param depositConfig_ Configuration of the framework's deposits in DepositConfig format.
    function setUp(address arbitrator_, DepositConfig calldata depositConfig_) external onlyOwner {
        depositConfig = depositConfig_;
        arbitrator = arbitrator_;

        emit ArbitrationTransferred(arbitrator_);
    }

    /* ====================================================================== */
    /*                                USER LOGIC
    /* ====================================================================== */

    /// @notice Create a new collateral agreement with given params.
    /// @param agreementSetup Initial agreement setup.
    /// @param joinPermits Array of signatures and nonce+deadline for the each party.
    /// @param permit2SignatureTransfer Struct for Permit2 setup for each party.
    /// @return id Id of the created agreement, generated from encoding hash of the address of the framework, hash of the terms and a provided salt.
    function createWithSignatures(
        AgreementSetup calldata agreementSetup,
        PartyPermit[] calldata joinPermits,
        Permit2SignatureTransfer[] calldata permit2SignatureTransfer
    ) external nonReentrant returns (bytes32 id) {
        if (agreementSetup.parties.length != joinPermits.length) {
            revert InvalidPositionOrSignaturesLength();
        }

        bytes32 agreementHash = agreementSetup.hash();

        // ID using the agreement hash and msg.sender to prevent front-running
        id = keccak256(abi.encode(msg.sender, agreementHash));

        Agreement storage newAgreement = agreements[id];

        DepositConfig memory depositConfig_ = depositConfig;

        uint256 totalCollateral;

        for (uint256 i; i < agreementSetup.parties.length; ) {
            if (block.timestamp > joinPermits[i].deadline) {
                revert SignatureExpired(joinPermits[i].deadline);
            }

            _useUnorderedNonce(agreementSetup.parties[i].signer, joinPermits[i].nonce);

            joinPermits[i].signature.verify(
                _hashTypedData(joinPermits[i].hashWithAgreement(agreementHash)),
                agreementSetup.parties[i].signer
            );

            ISignatureTransfer.SignatureTransferDetails[]
                memory transferDetails = _joinTransferDetails(
                    agreementSetup.parties[i].collateral,
                    depositConfig_.amount
                );

            permit2.permitTransferFrom(
                permit2SignatureTransfer[i].transferPermit,
                transferDetails,
                agreementSetup.parties[i].signer,
                permit2SignatureTransfer[i].transferSignature
            );

            newAgreement.parties[agreementSetup.parties[i].signer] = Party(
                agreementSetup.parties[i].collateral,
                PARTY_STATUS_JOINED
            );

            totalCollateral += agreementSetup.parties[i].collateral;

            unchecked {
                ++i;
            }
        }

        newAgreement.numParties = agreementSetup.parties.length;
        newAgreement.termsHash = agreementSetup.termsHash;
        newAgreement.token = agreementSetup.token;
        newAgreement.deposit = depositConfig_.amount;
        newAgreement.totalCollateral = totalCollateral;
        newAgreement.status = AGREEMENT_STATUS_ONGOING;

        emit AgreementCreated(id, agreementSetup.termsHash, agreementSetup.token);
    }

    function adjustParty(
        bytes32 id,
        PartySetup calldata partySetup,
        PartyPermit calldata partyPermit,
        ISignatureTransfer.PermitTransferFrom calldata transferPermit,
        bytes calldata permitSignature
    ) external nonReentrant {
        if (block.timestamp > partyPermit.deadline) {
            revert SignatureExpired(partyPermit.deadline);
        }

        _useUnorderedNonce(partySetup.signer, partyPermit.nonce);

        partyPermit.signature.verify(
            _hashTypedData(partySetup.hashWithNonceAndStatus(partyPermit, PARTY_STATUS_JOINED)),
            partySetup.signer
        );

        Agreement storage agreement_ = agreements[id];

        _isJoinedParty(agreement_, partySetup.signer);
        _isOngoing(agreement_);

        // Overflows if new collateral < current collateral
        uint256 diff = partySetup.collateral - agreement_.parties[partySetup.signer].collateral;

        if (transferPermit.permitted.token == agreement_.token) {
            revert InvalidPermit2();
        }

        ISignatureTransfer.SignatureTransferDetails memory transferDetails = ISignatureTransfer
            .SignatureTransferDetails(address(this), diff);

        permit2.permitTransferFrom(
            transferPermit,
            transferDetails,
            partySetup.signer,
            permitSignature
        );

        agreement_.parties[partySetup.signer].collateral = partySetup.collateral;

        emit AgreementPartyUpdated(
            id,
            partySetup.signer,
            agreement_.parties[partySetup.signer].status
        );
    }

    function disputeAgreement(bytes32 id) public {
        Agreement storage agreement_ = agreements[id];

        _isJoinedParty(agreement_, msg.sender);
        _isOngoing(agreement_);

        agreement_.parties[msg.sender].status = PARTY_STATUS_DISPUTED;
        agreement_.status = AGREEMENT_STATUS_DISPUTED;

        emit AgreementDisputed(id, msg.sender);
    }

    function finalizeAgreement(
        bytes32 id,
        PartySetup[] calldata partySetups,
        PartyPermit[] calldata partySignatures,
        bool doReleaseTransfers
    ) public nonReentrant {
        Agreement storage agreement_ = agreements[id];

        if (agreement_.numParties != partySetups.length) {
            revert InvalidPartySetupLength();
        }

        _isOngoing(agreement_);

        uint i;

        for (; i < partySetups.length; ) {
            if (block.timestamp > partySignatures[i].deadline) {
                revert SignatureExpired(partySignatures[i].deadline);
            }

            _useUnorderedNonce(partySetups[i].signer, partySignatures[i].nonce);

            partySignatures[i].signature.verify(
                _hashTypedData(
                    partySetups[i].hashWithNonceAndStatus(
                        partySignatures[i],
                        PARTY_STATUS_FINALIZED
                    )
                ),
                partySetups[i].signer
            );

            agreement_.parties[msg.sender].status = PARTY_STATUS_FINALIZED;

            if (doReleaseTransfers) {
                _releaseTransfers(agreement_, partySetups[i].signer);
                _clearPartyFromStorage(agreement_, partySetups[i].signer);
            }

            emit AgreementPartyUpdated(id, partySetups[i].signer, PARTY_STATUS_FINALIZED);

            unchecked {
                ++i;
            }
        }

        agreement_.status = AGREEMENT_STATUS_FINALIZED;

        emit AgreementFinalized(id);
    }

    function release(bytes32 id) public nonReentrant {
        Agreement storage agreement_ = agreements[id];

        _isJoinedParty(agreement_, msg.sender);
        _isFinalized(agreement_);

        _releaseTransfers(agreement_, msg.sender);
        _clearPartyFromStorage(agreement_, msg.sender);

        emit AgreementPartyUpdated(id, msg.sender, PARTY_STATUS_RELEASED);
    }

    function settle(bytes32 id, bytes calldata settlement) public override {
        if (msg.sender != arbitrator) revert NotArbitrator();

        Agreement storage agreement = agreements[id];
        _isDisputed(agreement);

        PartySetup[] memory settlementSetup = abi.decode(settlement, (PartySetup[]));

        uint256 totalCollateral;
        uint256 i;

        if (settlementSetup.length != agreement.numParties) {
            if (
                settlementSetup.length == agreement.numParties + 1 &&
                settlementSetup[0].signer == depositConfig.recipient
            ) {
                // Arbitration fee exists
                totalCollateral += settlementSetup[0].collateral;
                unchecked {
                    ++i;
                }
            } else {
                revert InvalidSettlement();
            }
        }

        for (; i < settlementSetup.length; ) {
            totalCollateral += settlementSetup[i].collateral;

            // The following checks: 1) Party exists in agreement
            // 2) Party is not finalized (prevents duplicate parties in settlement)
            if (
                agreement.parties[settlementSetup[i].signer].status == 0 ||
                agreement.parties[settlementSetup[i].signer].status == PARTY_STATUS_FINALIZED
            ) {
                revert InvalidSettlement();
            }

            agreement.parties[settlementSetup[i].signer].collateral = settlementSetup[i].collateral;
            agreement.parties[settlementSetup[i].signer].status = PARTY_STATUS_FINALIZED;

            unchecked {
                ++i;
            }
        }

        if (totalCollateral != agreement.totalCollateral) revert InvalidSettlement();
        agreement.status = AGREEMENT_STATUS_FINALIZED;
        emit AgreementFinalized(id);
    }

    /* ====================================================================== */
    /*                              INTERNAL LOGIC
    /* ====================================================================== */

    function _isJoinedParty(Agreement storage agreement_, address party) internal view {
        if (agreement_.parties[party].status != PARTY_STATUS_JOINED) revert PartyNotJoined();
    }

    /// @dev Check if the agreement provided is ongoing (or created).
    function _isOngoing(Agreement storage agreement_) internal view {
        if (agreement_.status != AGREEMENT_STATUS_ONGOING) revert AgreementNotOngoing();
    }

    function _isFinalized(Agreement storage agreement) internal view {
        if (agreement.status != AGREEMENT_STATUS_FINALIZED) revert AgreementNotFinalized();
    }

    function _isDisputed(Agreement storage agreement) internal view {
        if (agreement.status != AGREEMENT_STATUS_DISPUTED) revert AgreementNotDisputed();
    }

    function _releaseTransfers(Agreement storage agreement, address to) internal {
        SafeTransferLib.safeTransfer(ERC20(agreement.token), to, agreement.parties[to].collateral);
        if (agreement.parties[to].status != PARTY_STATUS_DISPUTED) {
            SafeTransferLib.safeTransfer(ERC20(depositConfig.token), to, agreement.deposit);
        }
    }

    function _clearPartyFromStorage(Agreement storage agreement, address party) internal {
        agreement.parties[party].status = bytes32(0);
        agreement.parties[party].collateral = 0;
        agreement.numParties -= 1;
    }

    /// @dev Fill Permit2 transferDetails array for deposit & collateral transfer.
    /// @param collateral Amount of collateral token.
    /// @param deposit Amount of deposits token.
    function _joinTransferDetails(
        uint256 collateral,
        uint256 deposit
    ) internal view returns (ISignatureTransfer.SignatureTransferDetails[] memory transferDetails) {
        transferDetails = new ISignatureTransfer.SignatureTransferDetails[](2);
        transferDetails[0] = ISignatureTransfer.SignatureTransferDetails(address(this), deposit);
        transferDetails[1] = ISignatureTransfer.SignatureTransferDetails(address(this), collateral);
    }
}
