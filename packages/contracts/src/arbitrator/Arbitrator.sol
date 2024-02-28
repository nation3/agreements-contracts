// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import { console2 } from "forge-std/console2.sol";

import { ISignatureTransfer } from "permit2/src/interfaces/ISignatureTransfer.sol";

import { ResolutionStatus, Resolution } from "src/arbitrator/ArbitratorTypes.sol";
import { IArbitrable } from "src/arbitrator/IArbitrable.sol";
import { IArbitrator } from "src/arbitrator/IArbitrator.sol";

import { DepositConfig } from "src/arbitrator/ArbitratorTypes.sol";
import { Controlled } from "src/utils/Controlled.sol";
import { Toggleable } from "src/utils/Toggleable.sol";

/// @notice Contract with the power to arbitrate Nation3 arbitrable contracts.
/// The DAO owns this contract and set a controller to operate it.
/// The owner sets the working parameters.
/// The owner can disable submissions and executions at any time.
/// The owner can replace the controller at any time.
/// The execution of a resolution is locked during a period after submission.
/// Any of the parties of a settlement can appeal a resolution before is executed.
/// The owner can override appeals by endorsing resolutions.
/// Anyone can execute resolutions.
contract Arbitrator is IArbitrator, Controlled, Toggleable {
    /// @notice Address of the Permit2 contract deployment.
    ISignatureTransfer public immutable permit2;

    /// @notice Appeals deposits configuration.
    DepositConfig public deposits;

    /// @notice Time (in seconds) between when a resolution is submitted and it's executable.
    uint256 public lockPeriod;

    /// @dev Resolution data by resolution id.
    mapping(bytes32 => Resolution) internal resolution;

    /// @notice Retrieve resolution details.
    /// @param id Id of the resolution to return data from.
    /// @return details Data struct of the resolution.
    function resolutionDetails(bytes32 id) external view returns (Resolution memory details) {
        return resolution[id];
    }

    constructor(ISignatureTransfer permit2_, address owner) Controlled(owner, owner) {
        permit2 = permit2_;
    }

    /// @notice Setup arbitrator variables.
    /// @param lockPeriod_ Duration of the resolution lock period.
    /// @param enabled_ Status of the arbitrator.
    /// @param deposits_ Configuration of the appeal's deposits in DepositConfig format.
    function setUp(
        uint256 lockPeriod_,
        bool enabled_,
        DepositConfig calldata deposits_
    ) external onlyOwner {
        lockPeriod = lockPeriod_;
        enabled = enabled_;
        deposits = deposits_;
    }

    /// @inheritdoc IArbitrator
    /// @dev Only controller is able to submit resolutions.
    function submitResolution(
        IArbitrable framework,
        bytes32 dispute,
        string calldata metadataURI,
        bytes calldata settlement
    ) public isEnabled onlyController returns (bytes32 id) {
        id = keccak256(abi.encodePacked(framework, dispute));
        Resolution storage resolution_ = resolution[id];

        if (resolution_.status == ResolutionStatus.Executed) {
            revert ResolutionIsExecuted();
        }

        bytes32 settlementEncoding = keccak256(abi.encode(settlement));
        resolution_.status = ResolutionStatus.Submitted;
        resolution_.settlement = settlementEncoding;
        resolution_.metadataURI = metadataURI;
        resolution_.unlockTime = block.timestamp + lockPeriod;

        emit ResolutionSubmitted(address(framework), dispute, id, settlementEncoding);
    }

    /// @inheritdoc IArbitrator
    function executeResolution(
        IArbitrable framework,
        bytes32 agreement,
        bytes calldata settlement
    ) public isEnabled {
        bytes32 id = keccak256(abi.encodePacked(framework, agreement));
        Resolution storage resolution_ = resolution[id];

        if (resolution_.status == ResolutionStatus.Appealed) {
            revert ResolutionIsAppealed();
        }
        if (resolution_.status == ResolutionStatus.Executed) {
            revert ResolutionIsExecuted();
        }
        if (
            resolution_.status != ResolutionStatus.Endorsed &&
            block.timestamp < resolution_.unlockTime
        ) {
            revert ResolutionIsLocked();
        }
        bytes32 settlementEncoding = keccak256(abi.encode(settlement));
        if (resolution_.settlement != settlementEncoding) {
            revert SettlementPositionsMustMatch();
        }

        console2.logBytes32(id);

        resolution_.status = ResolutionStatus.Executed;

        // framework.settleDispute(dispute, settlement);
        framework.settle(agreement, settlement); // Fix this.

        emit ResolutionExecuted(id, settlementEncoding);
    }

    /// @inheritdoc IArbitrator
    function appealResolution(
        bytes32 id,
        bytes calldata settlement,
        ISignatureTransfer.PermitTransferFrom memory permit,
        bytes calldata signature
    ) external {
        Resolution storage resolution_ = resolution[id];

        if (resolution_.status == ResolutionStatus.Idle) {
            revert NonExistentResolution();
        }
        if (resolution_.status == ResolutionStatus.Executed) {
            revert ResolutionIsExecuted();
        }
        if (resolution_.status == ResolutionStatus.Endorsed) {
            revert ResolutionIsEndorsed();
        }

        DepositConfig memory deposit = deposits;
        if (permit.permitted.token != deposit.token) revert InvalidPermit();
        bytes32 settlementEncoding = keccak256(abi.encode(settlement));
        if (resolution_.settlement != settlementEncoding) {
            revert SettlementPositionsMustMatch();
        }
        // if (!_isParty(msg.sender, settlement)) revert NotPartOfSettlement();
        // call framework to check if msg.sender CAN appear, then appeal if so.

        resolution_.status = ResolutionStatus.Appealed;

        ISignatureTransfer.SignatureTransferDetails memory transferDetails = ISignatureTransfer
            .SignatureTransferDetails(deposit.recipient, deposit.amount);
        permit2.permitTransferFrom(permit, transferDetails, msg.sender, signature);

        emit ResolutionAppealed(id, settlementEncoding, msg.sender);
    }

    /// @inheritdoc IArbitrator
    function endorseResolution(bytes32 id, bytes32 settlement) external onlyOwner {
        Resolution storage resolution_ = resolution[id];

        if (resolution_.status == ResolutionStatus.Idle) {
            revert NonExistentResolution();
        }
        if (resolution_.status == ResolutionStatus.Executed) {
            revert ResolutionIsExecuted();
        }
        if (resolution_.settlement != settlement) {
            revert SettlementPositionsMustMatch();
        }

        resolution_.status = ResolutionStatus.Endorsed;

        emit ResolutionEndorsed(id, settlement);
    }
}
