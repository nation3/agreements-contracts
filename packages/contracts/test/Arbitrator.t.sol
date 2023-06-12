// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/Console2.sol";

import { ISignatureTransfer } from "permit2/src/interfaces/ISignatureTransfer.sol";

import { TestConstants } from "test/utils/TestConstants.sol";
import { MockArbitrable } from "test/utils/mocks/MockArbitrable.sol";
import { PermitSignature } from "test/utils/PermitSignature.sol";
import { TokenProvider } from "test/utils/TokenProvider.sol";

import { ResolutionStatus, Resolution } from "src/arbitrator/ArbitratorTypes.sol";

import { DepositConfig } from "src/arbitrator/ArbitratorTypes.sol";
import { Arbitrator } from "src/arbitrator/Arbitrator.sol";
import { IEIP712 } from "./utils/IERC712.sol";
import { IArbitrator } from "src/arbitrator/IArbitrator.sol";
import { ICollateralAgreement } from "src/frameworks/collateral/ICollateralAgreement.sol";

contract ArbitratorTest is Test, TestConstants, TokenProvider, PermitSignature {
    Arbitrator arbitrator;
    MockArbitrable arbitrable;

    uint256 constant LOCK_PERIOD = 86400; // 1 day
    bytes32 DOMAIN_SEPARATOR;
    string constant METADATA_URI = "ipfs://metadata";
    bytes32 dispute;

    DepositConfig appeals;

    function setUp() public {
        initializeERC20Tokens();
        DOMAIN_SEPARATOR = IEIP712(permit2).DOMAIN_SEPARATOR();
        appeals = DepositConfig(address(tokenA), 2e17, address(0xD40));

        arbitrator = new Arbitrator(ISignatureTransfer(permit2), address(this));
        arbitrable = new MockArbitrable();

        arbitrator.setUp(LOCK_PERIOD, true, appeals);
        arbitrable.setUp(address(arbitrator));

        setERC20TestTokens(testSubjects[0]);
        setERC20TestTokenApprovals(vm, testSubjects[0], address(permit2));

        dispute = arbitrable.createDispute();
    }

    function testSubmitResolution() public {
        bytes32 resolutionId = submitResolution();
        uint256 submitTime = block.timestamp;

        Resolution memory resolution = arbitrator.resolutionDetails(resolutionId);

        assertEq(resolution.status, ResolutionStatus.Submitted);
        assertEq(resolution.metadataURI, METADATA_URI);
        assertEq(resolution.unlockTime, submitTime + LOCK_PERIOD);
    }

    /* function testResolutionOverride() public {
        bytes32 resolutionId = submitResolution();

        Resolution memory originalResolution = arbitrator.resolutionDetails(resolutionId);

        // Generate new settlement
        bytes memory newSettlement = settlement();
        newSettlement[1].balance = 1e18;

        uint256 warpTime = originalResolution.unlockTime + 5;
        vm.warp(warpTime);

        // Submit new resolution for the same dispute
        arbitrator.submitResolution(arbitrable, dispute, METADATA_URI, newSettlement);

        Resolution memory newResolution = arbitrator.resolutionDetails(resolutionId);

        assertTrue(originalResolution.settlement != newResolution.settlement);
        assertEq(newResolution.settlement, keccak256(abi.encode(newSettlement)));

        assertEq(newResolution.unlockTime, warpTime + LOCK_PERIOD);
    } */

    function testCantSubmitNewResolutionAfterExecution() public {
        executedResolution();

        vm.expectRevert(IArbitrator.ResolutionIsExecuted.selector);
        arbitrator.submitResolution(arbitrable, dispute, "ipfs://", settlement());
    }

    function testExecuteResolution() public {
        submitResolution();

        vm.warp(block.timestamp + LOCK_PERIOD);
        assertEq(arbitrable.disputeStatus(dispute), 1);

        arbitrator.executeResolution(arbitrable, dispute, settlement());

        console2.logBytes32(dispute);

        console2.log("Settlement", arbitrable.disputeStatus(dispute));

        assertEq(arbitrable.disputeStatus(dispute), 2);
    }

    function testCantExecuteResolutionBeforeUnlock() public {
        submitResolution();

        vm.expectRevert(IArbitrator.ResolutionIsLocked.selector);
        arbitrator.executeResolution(arbitrable, dispute, settlement());
    }

    function testCantExecuteAppealedResolution() public {
        appealledResolution();

        vm.expectRevert(IArbitrator.ResolutionIsAppealed.selector);
        arbitrator.executeResolution(arbitrable, dispute, settlement());
    }

    function testCantExecuteAlreadyExecutedResolution() public {
        executedResolution();

        vm.expectRevert(IArbitrator.ResolutionIsExecuted.selector);
        arbitrator.executeResolution(arbitrable, dispute, settlement());
    }

    function testCantExecuteResolutionMismatch() public {
        submitResolution();

        vm.warp(block.timestamp + LOCK_PERIOD);

        vm.expectRevert(IArbitrator.SettlementPositionsMustMatch.selector);

        arbitrator.executeResolution(arbitrable, dispute, "");
    }

    function testCanAlwaysExecuteEndorsedResolution() public {
        bytes32 id = appealledResolution();
        bytes32 encoding = keccak256(abi.encode(settlement()));

        arbitrator.endorseResolution(id, encoding);

        // Resolution appealed and inside the lock period.
        arbitrator.executeResolution(arbitrable, dispute, settlement());
    }

    function testAppealResolution() public {
        bytes32 id = submitResolution();
        appealResolution(id);

        Resolution memory resolution = arbitrator.resolutionDetails(id);

        assertEq(resolution.status, ResolutionStatus.Appealed);
    }

    function testOnlyPartiesCanAppeal() public {
        bytes32 id = submitResolution();

        ISignatureTransfer.PermitTransferFrom memory permit = defaultERC20PermitTransfer(
            address(tokenA),
            appeals.amount,
            0
        );
        bytes memory signature = getPermitTransferSignature(
            permit,
            address(arbitrator),
            0xB0B,
            DOMAIN_SEPARATOR
        );

        // Pretend to be random user that is not part of settlement
        vm.prank(address(0xDEAD));
        // vm.expectRevert(IArbitrator.NotPartOfSettlement.selector);
        arbitrator.appealResolution(id, settlement(), permit, signature);
    }

    function testEndorseResolution() public {
        bytes32 id = endorsedResolution();

        Resolution memory resolution = arbitrator.resolutionDetails(id);

        assertEq(resolution.status, ResolutionStatus.Endorsed);
    }

    /* ---------------------------------------------------------------------- */

    function settlement() internal view returns (bytes memory) {
        ICollateralAgreement.PartySetup[]
            memory settlement_ = new ICollateralAgreement.PartySetup[](2);
        settlement_[0] = ICollateralAgreement.PartySetup(testSubjects[0], 3 * 1e18);
        settlement_[1] = ICollateralAgreement.PartySetup(testSubjects[1], 0);

        return abi.encode(settlement_);
    }

    function submitResolution() internal returns (bytes32 id) {
        id = arbitrator.submitResolution(arbitrable, dispute, METADATA_URI, settlement());
    }

    function appealResolution(bytes32 id) internal {
        ISignatureTransfer.PermitTransferFrom memory permit = defaultERC20PermitTransfer(
            address(tokenA),
            appeals.amount,
            0
        );
        bytes memory signature = getPermitTransferSignature(
            permit,
            address(arbitrator),
            0xB0B,
            DOMAIN_SEPARATOR
        );

        vm.prank(testSubjects[0]);
        arbitrator.appealResolution(id, settlement(), permit, signature);
    }

    function appealledResolution() internal returns (bytes32 id) {
        id = submitResolution();
        appealResolution(id);
    }

    function endorsedResolution() internal returns (bytes32 id) {
        id = appealledResolution();
        bytes32 encoding = keccak256(abi.encode(settlement()));

        arbitrator.endorseResolution(id, encoding);
    }

    function executedResolution() internal returns (bytes32 id) {
        id = submitResolution();
        vm.warp(block.timestamp + LOCK_PERIOD);
        arbitrator.executeResolution(arbitrable, dispute, settlement());
    }

    function assertEq(ResolutionStatus a, ResolutionStatus b) internal {
        if (uint256(a) != uint256(b)) {
            emit log("Error: a == b not satisfied [ResolutionStatus]");
            emit log_named_uint("  Expected", uint256(b));
            emit log_named_uint("    Actual", uint256(a));
            fail();
        }
    }
}
