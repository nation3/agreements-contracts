// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {ISignatureTransfer} from "permit2/src/interfaces/ISignatureTransfer.sol";
import {IArbitrable, OnlyArbitrator} from "src/interfaces/IArbitrable.sol";
import {IAgreementFramework} from "src/interfaces/IAgreementFramework.sol";
import {
    AgreementParams,
    PositionParams,
    PositionStatus,
    AgreementStatus,
    PositionData,
    AgreementData
} from "src/interfaces/Agreement.sol";
import "src/interfaces/AgreementErrors.sol";
import "src/interfaces/ArbitrationErrors.sol";

import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";
import {Permit2} from "permit2/src/Permit2.sol";
import {CriteriaResolver, CriteriaResolution} from "src/libraries/CriteriaResolution.sol";

/// @notice Data structure for positions in the agreement.
struct Position {
    /// @dev Address of the owner of the position.
    address party;
    /// @dev Amount of agreement tokens in the position.
    uint256 balance;
    /// @dev Amount of fee tokens deposited for dispute.
    uint256 deposit;
    /// @dev Status of the position.
    PositionStatus status;
}

/// @dev Data estructure for collateral agreements.
struct Agreement {
    /// @dev Hash of the detailed terms of the agreement.
    bytes32 termsHash;
    /// @dev Required amount to join or merkle root of (address,amount).
    uint256 criteria;
    /// @dev URI of the metadata of the agreement.
    string metadataURI;
    /// @dev ERC20 token to use as collateral.
    address token;
    /// @dev Total amount of collateral tokens deposited in the agreement.
    uint256 balance;
    /// @dev Number of finalizations.
    uint256 finalizations;
    /// @dev Signal if agreement is disputed.
    bool disputed;
    /// @dev List of parties involved in the agreement.
    address[] party;
    /// @dev Position by party.
    mapping(address => Position) position;
}

/// @dev Data estructure to configure framework fees.
struct FeeConfig {
    /// @dev Address of the ERC20 token used for fees.
    address token;
    /// @dev Amount of tokens to charge as fee.
    uint256 amount;
    /// @dev Address recipient of the fees collected.
    address recipient;
}

contract CollateralAgreementFramework is IAgreementFramework {
    using SafeTransferLib for ERC20;

    /// @notice Address of the Permit2 contract deployment.
    Permit2 public permit2;

    /// @notice Fees configuration.
    FeeConfig public fees;

    /// @inheritdoc IArbitrable
    address public arbitrator;

    /// @dev Agreements by id
    mapping(bytes32 => Agreement) internal agreement;

    /// @notice Set up framework params;
    /// @param permit2_ Address of the Permti2 contract deployment.
    /// @param arbitrator_ Address allowed to settle disputes.
    /// @param fees_ Configuration of the framework's fees in FeeConfig format.
    function setUp(Permit2 permit2_, address arbitrator_, FeeConfig calldata fees_) external {
        permit2 = permit2_;
        arbitrator = arbitrator_;
        fees = fees_;
    }

    /* ====================================================================== */
    /*                                  VIEWS
    /* ====================================================================== */

    /// @notice Retrieve basic data of an agreement.
    /// @param id Id of the agreement to return data from.
    /// @return data Data struct of the agreement.
    function agreementData(bytes32 id) external view returns (AgreementData memory data) {
        Agreement storage agreement_ = agreement[id];

        data = AgreementData(
            agreement_.termsHash,
            agreement_.criteria,
            agreement_.metadataURI,
            agreement_.token,
            agreement_.balance,
            _agreementStatus(agreement_)
        );
    }

    /// @notice Retrieve positions of an agreement.
    /// @param id Id of the agreement to return data from.
    /// @return Array of the positions of the agreement in PositionData structs.
    function agreementPositions(bytes32 id) external view returns (PositionData[] memory) {
        Agreement storage agreement_ = agreement[id];
        uint256 partyLength = agreement_.party.length;
        PositionData[] memory positions = new PositionData[](partyLength);

        for (uint256 i = 0; i < partyLength; i++) {
            address party = agreement_.party[i];
            Position memory position = agreement_.position[party];
            positions[i] = PositionData(position.party, position.balance, position.status);
        }

        return positions;
    }

    /// @dev Retrieve a simplified status of the agreement from its attributes.
    function _agreementStatus(Agreement storage agreement_) internal view virtual returns (AgreementStatus) {
        if (agreement_.party.length > 0) {
            if (agreement_.finalizations >= agreement_.party.length) {
                return AgreementStatus.Finalized;
            }
            if (agreement_.disputed) return AgreementStatus.Disputed;
            // else
            return AgreementStatus.Ongoing;
        } else if (agreement_.criteria != 0) {
            return AgreementStatus.Created;
        }
        revert NonExistentAgreement();
    }

    /* ====================================================================== */
    /*                                USER LOGIC
    /* ====================================================================== */

    /// @notice Create a new collateral agreement with given params.
    /// @param params Struct of agreement params.
    /// @param salt Extra bytes to avoid collisions between agreements with the same terms hash in the framework.
    /// @return id Id of the agreement created, generated from encoding hash of the address of the framework, hash of the terms and a provided salt.
    function createAgreement(AgreementParams calldata params, bytes32 salt) external returns (bytes32 id) {
        id = keccak256(abi.encode(address(this), params.termsHash, salt));
        Agreement storage newAgreement = agreement[id];

        newAgreement.termsHash = params.termsHash;
        newAgreement.criteria = params.criteria;
        newAgreement.metadataURI = params.metadataURI;
        newAgreement.token = params.token;

        emit AgreementCreated(id, params.termsHash, params.criteria, params.metadataURI, params.token);
    }


    /// @inheritdoc IAgreementFramework
    function joinAgreement(
        bytes32 id,
        CriteriaResolver calldata resolver,
        ISignatureTransfer.PermitBatchTransferFrom memory permit,
        bytes calldata signature
    ) external override {
        Agreement storage agreement_ = agreement[id];
        _canJoinAgreement(agreement_, resolver);
        FeeConfig memory fee = fees;

        // validate permit tokens & generate transfer details
        if (permit.permitted[0].token != fee.token) revert InvalidPermit();
        if (permit.permitted[1].token != agreement_.token) revert InvalidPermit();
        ISignatureTransfer.SignatureTransferDetails[] memory transferDetails =
            _transferDetails(resolver.balance, fee.amount);

        permit2.permitTransferFrom(permit, transferDetails, msg.sender, signature);

        _addPosition(agreement_, PositionParams(msg.sender, resolver.balance), fee.amount);

        emit AgreementJoined(id, msg.sender, resolver.balance);
    }

    /// @inheritdoc IAgreementFramework
    function finalizeAgreement(bytes32 id) external {
        Agreement storage agreement_ = agreement[id];

        _canFinalizeAgreement(agreement_);

        agreement_.position[msg.sender].status = PositionStatus.Finalized;
        agreement_.finalizations += 1;

        emit AgreementPositionUpdated(id, msg.sender, agreement_.position[msg.sender].balance, PositionStatus.Finalized);

        if (_isFinalized(agreement_)) emit AgreementFinalized(id);
    }

    /// @inheritdoc IAgreementFramework
    function disputeAgreement(bytes32 id) external override {
        Agreement storage agreement_ = agreement[id];

        _canDisputeAgreement(agreement_);

        FeeConfig memory fee = fees;
        Position storage position = agreement_.position[msg.sender];

        SafeTransferLib.safeTransfer(ERC20(fee.token), fee.recipient, position.deposit);

        agreement_.disputed = true;
        position.status = PositionStatus.Disputed;
        position.deposit = 0;

        emit AgreementDisputed(id, msg.sender);
    }

    /// @inheritdoc IAgreementFramework
    /// @dev Requires the agreement to be finalized.
    function withdrawFromAgreement(bytes32 id) external override {
        Agreement storage agreement_ = agreement[id];

        if (!_isFinalized(agreement_)) revert AgreementNotFinalized();
        if (!_isPartOfAgreement(agreement_, msg.sender)) revert NoPartOfAgreement();

        Position storage position = agreement_.position[msg.sender];
        uint256 withdrawBalance = position.balance;
        uint256 withdrawDeposit = position.deposit;
        position.balance = 0;
        position.deposit = 0;
        position.status = PositionStatus.Withdrawn;

        SafeTransferLib.safeTransfer(ERC20(agreement_.token), msg.sender, withdrawBalance);
        SafeTransferLib.safeTransfer(ERC20(fees.token), msg.sender, withdrawDeposit);

        emit AgreementPositionUpdated(id, msg.sender, 0, PositionStatus.Withdrawn);
    }

    /* ====================================================================== */
    /*                              Arbitration
    /* ====================================================================== */

    /// @inheritdoc IArbitrable
    /// @dev Allows the arbitrator to finalize an agreement in dispute with the provided set of positions.
    /// @dev The provided settlement parties must match the parties of the agreement and the total balance of the settlement must match the previous agreement balance.
    function settleDispute(bytes32 id, PositionParams[] calldata settlement) external override {
        Agreement storage agreement_ = agreement[id];
        if (msg.sender != arbitrator) revert OnlyArbitrator();
        if (!agreement_.disputed) revert AgreementNotDisputed();
        if (_isFinalized(agreement_)) revert AgreementIsFinalized();

        uint256 positionsLength = settlement.length;
        uint256 newBalance;

        if (positionsLength != agreement_.party.length) revert SettlementPositionsMustMatch();
        for (uint256 i = 0; i < positionsLength; i++) {
            // Revert if previous positions parties do not match.
            if (agreement_.party[i] != settlement[i].party) revert SettlementPositionsMustMatch();

            _updatePosition(agreement_, settlement[i], PositionStatus.Finalized);
            newBalance += settlement[i].balance;

            emit AgreementPositionUpdated(id, settlement[i].party, settlement[i].balance, PositionStatus.Finalized);
        }

        if (newBalance != agreement_.balance) revert SettlementBalanceMustMatch();

        // Finalize agreement.
        agreement_.finalizations = positionsLength;
        emit AgreementFinalized(id);
    }

    /* ====================================================================== */
    /*                              INTERNAL LOGIC
    /* ====================================================================== */

    /// @dev Check if caller can join an agreement with the criteria resolver provided.
    /// @param agreement_ Agreement to check.
    /// @param resolver Criteria resolver to check against criteria.
    function _canJoinAgreement(Agreement storage agreement_, CriteriaResolver calldata resolver) internal view {
        if (agreement_.disputed) revert AgreementIsDisputed();
        if (_isFinalized(agreement_)) revert AgreementIsFinalized();
        if (_isPartOfAgreement(agreement_, msg.sender)) revert PartyAlreadyJoined();
        if (msg.sender != resolver.account) revert InvalidCriteria();

        CriteriaResolution.validateCriteria(bytes32(agreement_.criteria), resolver);
    }

    function _canFinalizeAgreement(Agreement storage agreement_) internal view {
        if (agreement_.disputed) revert AgreementIsDisputed();
        if (!_isPartOfAgreement(agreement_, msg.sender)) revert NoPartOfAgreement();
        if (agreement_.position[msg.sender].status == PositionStatus.Finalized) {
            revert PartyAlreadyFinalized();
        }
    }

    /// @dev Check if caller can dispute an agreement.
    /// @dev Requires the caller to be part of the agreement.
    /// @dev Can be perform only once per agreement.
    /// @param agreement_ Agreement to check.
    function _canDisputeAgreement(Agreement storage agreement_) internal view returns (bool) {
        if (agreement_.disputed) revert AgreementIsDisputed();
        if (_isFinalized(agreement_)) revert AgreementIsFinalized();
        if (!_isPartOfAgreement(agreement_, msg.sender)) revert NoPartOfAgreement();
        return true;
    }

    /// @dev Check if an agreement is finalized.
    /// @dev An agreement is finalized when all positions are finalized.
    /// @param agreement_ Agreement to check.
    /// @return A boolean signaling if the agreement is finalized or not.
    function _isFinalized(Agreement storage agreement_) internal view returns (bool) {
        return (agreement_.party.length > 0 && agreement_.finalizations >= agreement_.party.length);
    }

    /// @dev Check if an account is part of an agreement.
    /// @param agreement_ Agreement to check.
    /// @param account Account to check.
    /// @return A boolean signaling if the account is part of the agreement or not.
    function _isPartOfAgreement(Agreement storage agreement_, address account) internal view returns (bool) {
        return ((agreement_.party.length > 0) && (agreement_.position[account].party == account));
    }

    /// @dev Fill Permit2 transferDetails array for fees & collateral transfer
    /// @param collateral Amount of collateral token
    /// @param deposit Amount of fees token
    function _transferDetails(uint256 collateral, uint256 deposit)
        internal
        view
        returns (ISignatureTransfer.SignatureTransferDetails[] memory transferDetails)
    {
        transferDetails = new ISignatureTransfer.SignatureTransferDetails[](2);
        transferDetails[0] = ISignatureTransfer.SignatureTransferDetails(address(this), deposit);
        transferDetails[1] = ISignatureTransfer.SignatureTransferDetails(address(this), collateral);
    }

    function _addPosition(Agreement storage agreement_, PositionParams memory position, uint256 deposit) internal {
        // uint256 partyId = agreement_.party.length;
        agreement_.party.push(position.party);
        agreement_.position[position.party] = Position(position.party, position.balance, deposit, PositionStatus.Joined);
        agreement_.balance += position.balance;
    }

    function _updatePosition(Agreement storage agreement_, PositionParams memory params, PositionStatus status)
        internal
    {
        Position storage position = agreement_.position[params.party];
        agreement_.position[params.party] = Position(params.party, params.balance, position.deposit, status);
    }
}
