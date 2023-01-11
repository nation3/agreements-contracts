// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";

import { IAllowanceTransfer } from "permit2/src/interfaces/IAllowanceTransfer.sol";
import { ISignatureTransfer } from "permit2/src/interfaces/ISignatureTransfer.sol";

import { SafeCast160 } from "permit2/src/libraries/SafeCast160.sol";
import { PermitHash } from "permit2/src/libraries/PermitHash.sol";
import { Permit2 } from "permit2/src/Permit2.sol";
import { ERC20 } from "solmate/src/tokens/ERC20.sol";

import { CriteriaProvider } from "test/utils/AgreementProvider.sol";
import { PermitSignature, TokenPair } from "test/utils/PermitSignature.sol";
import { TokenProvider } from "test/utils/TokenProvider.sol";


import { AgreementParams, PositionParams, AgreementData, PositionData, PositionStatus, AgreementStatus } from "src/interfaces/AgreementTypes.sol";
import "src/interfaces/AgreementErrors.sol";
import {SettlementPositionsMustMatch, SettlementBalanceMustMatch } from "src/interfaces/ArbitrationErrors.sol";
import { CriteriaResolver } from "src/interfaces/CriteriaTypes.sol";
import { OnlyArbitrator } from "src/interfaces/IArbitrable.sol";

import { InvalidCriteriaProof } from "src/libraries/CriteriaResolution.sol";
import { CriteriaResolver } from "src/libraries/CriteriaResolution.sol";
import { CollateralAgreementFramework, DepositConfig } from "src/frameworks/CollateralAgreement.sol";


contract CollateralAgreementFrameworkTest is Test, TokenProvider, CriteriaProvider, PermitSignature {
    using SafeCast160 for uint256;

    CollateralAgreementFramework framework;

    bytes32 DOMAIN_SEPARATOR;
    address arbitrator = address(0xB055);

    AgreementParams params;
    DepositConfig deposits;

    function setUp() public {
        initializeERC20Tokens();
        DOMAIN_SEPARATOR = permit2.DOMAIN_SEPARATOR();
        deposits = DepositConfig(address(tokenB), 1e17, arbitrator);

        framework = new CollateralAgreementFramework(permit2);

        framework.setUp(arbitrator, deposits);

        setERC20TestTokens(bob);
        setERC20TestTokens(alice);
        setERC20TestTokenApprovals(vm, bob, address(permit2));
        setERC20TestTokenApprovals(vm, alice, address(permit2));
    }

    function testCreateAgreement() public {
        bytes32 agreementId = createAgreement();

        AgreementData memory createdAgreement = framework.agreementData(agreementId);

        assertEq(createdAgreement.termsHash, params.termsHash);
        assertEq(createdAgreement.criteria, params.criteria);
        assertEq(createdAgreement.metadataURI, params.metadataURI);
        assertEq(createdAgreement.token, params.token);
        assertEq(createdAgreement.status, AgreementStatus.Created);
    }

    function testDeterministicId(bytes32 termsHash, uint256 criteria, bytes32 salt) public {
        bytes32 id = keccak256(abi.encode(address(framework), termsHash, salt));
        bytes32 agreementId = framework.createAgreement(AgreementParams(termsHash, criteria, "ipfs", address(tokenA)), salt);

        assertEq(id, agreementId);
    }

    /* ====================================================================== //
                                    JOIN TESTS
    // ====================================================================== */

    function testJoinAgreement() public {
        bytes32 agreementId = createAgreement();
        uint256 bobBalance = balanceOf(params.token, bob);

        bobJoinsAgreement(agreementId);

        PositionData[] memory positions = framework.agreementPositions(agreementId);
        assertPosition(positions[0], bob, bobStake, PositionStatus.Joined);

        assertEq(balanceOf(params.token, bob), bobBalance - bobStake);
        assertEq(balanceOf(params.token, address(framework)), bobStake);
        assertEq(balanceOf(deposits.token, address(framework)), deposits.amount);
    }

    function testCantJoinNonExistentAgreement(bytes32 id) public {
        aliceExpectsErrorWhenJoining(id, InvalidCriteriaProof.selector);
    }

    function testCantJoinAgreementWithInvalidCriteria() public {
        bytes32 agreementId = createAgreement();

        CriteriaResolver memory resolver = CriteriaResolver(alice, 1e17, proofs[alice]);
        aliceExpectsErrorWhenJoining(agreementId, resolver, InvalidCriteriaProof.selector);
    }

    function testCantJoinAgreementMultipleTimes() public {
        bytes32 agreementId = createAgreement();
        aliceJoinsAgreement(agreementId);

        aliceExpectsErrorWhenJoining(agreementId, PartyAlreadyJoined.selector);
    }

    function testCantJoinDisputedAgreement() public {
        bytes32 agreementId = createAgreement();
        bobJoinsAgreement(agreementId);
        bobDisputesAgreement(agreementId);

        aliceExpectsErrorWhenJoining(agreementId, AgreementIsDisputed.selector);
    }

    function testCantJoinFinalizedAgreement() public {
        bytes32 agreementId = createAgreement();
        bobJoinsAgreement(agreementId);
        vm.prank(bob);
        framework.finalizeAgreement(agreementId);

        aliceExpectsErrorWhenJoining(agreementId, AgreementIsFinalized.selector);
    }

    function testAgreementStatusOngoing() public {
        bytes32 agreementId = createAgreement();
        bobJoinsAgreement(agreementId);

        AgreementData memory agreement = framework.agreementData(agreementId);
        assertEq(agreement.status, AgreementStatus.Ongoing);
    }

    /* ====================================================================== //
                                FINALIZATION TESTS
    // ====================================================================== */

    function testSingleFinalization() public {
        bytes32 agreementId = createAgreement();
        bobJoinsAgreement(agreementId);
        aliceJoinsAgreement(agreementId);

        vm.prank(bob);
        framework.finalizeAgreement(agreementId);

        PositionData[] memory positions = framework.agreementPositions(agreementId);
        assertPosition(positions[0], bob, bobStake, PositionStatus.Finalized);
        assertPosition(positions[1], alice, aliceStake, PositionStatus.Joined);

        AgreementData memory agreement = framework.agreementData(agreementId);
        assertEq(agreement.status, AgreementStatus.Ongoing);
    }

    function testFinalizationConsensus() public {
        bytes32 agreementId = createAgreement();
        bobJoinsAgreement(agreementId);
        aliceJoinsAgreement(agreementId);

        vm.prank(bob);
        framework.finalizeAgreement(agreementId);
        vm.prank(alice);
        framework.finalizeAgreement(agreementId);

        // Agreement is finalized
        AgreementData memory agreement = framework.agreementData(agreementId);
        assertEq(agreement.status, AgreementStatus.Finalized);
    }

    function testOnlyPartyCanFinalizeAgreement() public {
        bytes32 agreementId = createAgreement();
        bobJoinsAgreement(agreementId);

        aliceExpectsErrorWhenFinalizing(agreementId, NoPartOfAgreement.selector);
    }

    function testCantFinalizeDisputedAgreement() public {
        bytes32 agreementId = createAgreement();
        bobJoinsAgreement(agreementId);
        aliceJoinsAgreement(agreementId);

        vm.prank(bob);
        framework.disputeAgreement(agreementId);

        aliceExpectsErrorWhenFinalizing(agreementId, AgreementIsDisputed.selector);
    }

    function testCantFinalizeMultipleTimes() public {
        bytes32 agreementId = createAgreement();
        bobJoinsAgreement(agreementId);
        aliceJoinsAgreement(agreementId);

        vm.startPrank(bob);
        framework.finalizeAgreement(agreementId);

        vm.expectRevert(PartyAlreadyFinalized.selector);
        framework.finalizeAgreement(agreementId);
        vm.stopPrank();
    }

    /* ====================================================================== //
                                    DISPUTE TESTS
    // ====================================================================== */

    function testDisputeAgreement() public {
        bytes32 agreementId = createAgreement();

        bobJoinsAgreement(agreementId);
        aliceJoinsAgreement(agreementId);

        bobDisputesAgreement(agreementId);

        AgreementData memory agreement = framework.agreementData(agreementId);
        assertEq(agreement.status, AgreementStatus.Disputed);

        PositionData[] memory positions = framework.agreementPositions(agreementId);
        assertPosition(positions[0], bob, bobStake, PositionStatus.Disputed);
        assertPosition(positions[1], alice, aliceStake, PositionStatus.Joined);

        // dispute deposits transferred
        assertEq(balanceOf(deposits.token, deposits.recipient), deposits.amount);
    }

    function testOnlyPartyCanDisputeAgreement() public {
        bytes32 agreementId = createAgreement();
        bobJoinsAgreement(agreementId);

        vm.prank(alice);
        vm.expectRevert(NoPartOfAgreement.selector);
        framework.disputeAgreement(agreementId);
    }

    function testCantDisputeFinalizedAgreement() public {
        bytes32 agreementId = createAgreement();
        bobJoinsAgreement(agreementId);
        aliceJoinsAgreement(agreementId);

        vm.prank(bob);
        framework.finalizeAgreement(agreementId);
        vm.startPrank(alice);
        framework.finalizeAgreement(agreementId);

        vm.expectRevert(AgreementIsFinalized.selector);
        framework.disputeAgreement(agreementId);
    }

    /* ====================================================================== //
                              DISPUTE SETTLEMENT TESTS
    // ====================================================================== */

    function testSettlement() public {
        bytes32 disputeId = createDispute();
        PositionParams[] memory settlement = getValidSettlement();

        vm.prank(arbitrator);
        framework.settleDispute(disputeId, settlement);

        AgreementData memory agreement = framework.agreementData(disputeId);
        assertEq(agreement.status, AgreementStatus.Finalized);

        PositionData[] memory positions = framework.agreementPositions(disputeId);
        assertPosition(positions[0], bob, settlement[0].balance, PositionStatus.Finalized);
        assertPosition(positions[1], alice, settlement[1].balance, PositionStatus.Finalized);
    }

    function testOnlyCanSettleDisputedAgreements() public {
        bytes32 agreementId = createAgreement();
        bobJoinsAgreement(agreementId);
        aliceJoinsAgreement(agreementId);
        PositionParams[] memory settlement = getValidSettlement();

        vm.prank(arbitrator);
        vm.expectRevert(AgreementNotDisputed.selector);
        framework.settleDispute(agreementId, settlement);
    }

    function testOnlyArbitratorCanSettleDispute(address account) public {
        if (account == arbitrator) return;

        bytes32 disputeId = createDispute();
        PositionParams[] memory settlement = getValidSettlement();

        vm.prank(account);
        vm.expectRevert(OnlyArbitrator.selector);
        framework.settleDispute(disputeId, settlement);
    }

    function testSettlementMustMatchBalance() public {
        bytes32 disputeId = createDispute();
        PositionParams[] memory settlement = getValidSettlement();
        settlement[1].balance = aliceStake + bobStake;

        vm.prank(arbitrator);
        vm.expectRevert(SettlementBalanceMustMatch.selector);
        framework.settleDispute(disputeId, settlement);

        settlement[0].balance = 0;
        settlement[1].balance = bobStake;

        vm.prank(arbitrator);
        vm.expectRevert(SettlementBalanceMustMatch.selector);
        framework.settleDispute(disputeId, settlement);
    }

    function testSettlementMustMatchPositions() public {
        bytes32 disputeId = createDispute();
        PositionParams[] memory settlement = new PositionParams[](3);
        settlement[0] = PositionParams(bob, 0);
        settlement[1] = PositionParams(alice, aliceStake);
        settlement[2] = PositionParams(arbitrator, bobStake);

        vm.prank(arbitrator);
        vm.expectRevert(SettlementPositionsMustMatch.selector);
        framework.settleDispute(disputeId, settlement);

        settlement = new PositionParams[](1);
        settlement[0] = PositionParams(arbitrator, bobStake + aliceStake);

        vm.prank(arbitrator);
        vm.expectRevert(SettlementPositionsMustMatch.selector);
        framework.settleDispute(disputeId, settlement);
    }

    /* ====================================================================== //
                             AGREEMENT WITHDRAWAL TESTS
    // ====================================================================== */

    function testWithdrawFromAgreement() public {
        bytes32 agreementId = createAgreement();
        uint256 beforeBalance = balanceOf(params.token, bob);
        uint256 beforeDepositBalance = balanceOf(deposits.token, bob);

        bobJoinsAgreement(agreementId);
        vm.startPrank(bob);
        framework.finalizeAgreement(agreementId);
        framework.withdrawFromAgreement(agreementId);
        vm.stopPrank();

        // bob withdraws his collateral & deposit
        assertEq(balanceOf(params.token, bob), beforeBalance);
        assertEq(balanceOf(deposits.token, bob), beforeDepositBalance);
    }

    function testWithdrawAfterSettlement() public {
        bytes32 disputeId = createDispute();
        uint256 bobBalance = balanceOf(params.token, bob);
        uint256 bobDepositBalance = balanceOf(deposits.token, bob);
        uint256 aliceBalance = balanceOf(params.token, alice);
        uint256 aliceDepositBalance = balanceOf(deposits.token, alice);
 
        PositionParams[] memory settlement = getValidSettlement();

        vm.prank(arbitrator);
        framework.settleDispute(disputeId, settlement);

        vm.prank(bob);
        framework.withdrawFromAgreement(disputeId);
        vm.prank(alice);
        framework.withdrawFromAgreement(disputeId);

        // bob withdraws his collateral but no deposit
        assertEq(bobBalance, balanceOf(params.token, bob) - settlement[0].balance);
        assertEq(bobDepositBalance, balanceOf(deposits.token, bob));

        // alice withdraws her collateral & deposit
        assertEq(aliceBalance, balanceOf(params.token, alice) - settlement[1].balance);
        assertEq(aliceDepositBalance + deposits.amount, balanceOf(deposits.token, alice));
    }

    /* ---------------------------------------------------------------------- */

    function createAgreement() internal returns (bytes32 agreementId) {
        setDefaultAgreementParams();
        agreementId = framework.createAgreement(params, bytes32(""));
    }

    function createDispute() internal returns (bytes32 disputeId) {
        bytes32 agreementId = createAgreement();
        bobJoinsAgreement(agreementId);
        aliceJoinsAgreement(agreementId);

        vm.prank(bob);
        framework.disputeAgreement(agreementId);

        disputeId = agreementId;
    }

    function bobJoinsAgreement(bytes32 agreementId) internal {
        CriteriaResolver memory resolver = CriteriaResolver(bob, bobStake, proofs[bob]);

        TokenPair[] memory tokenPairs = getJoinTokenPairs(bobStake);
        ISignatureTransfer.PermitBatchTransferFrom memory permit = defaultERC20PermitMultiple(tokenPairs, 0);
        bytes memory signature = getPermitBatchTransferSignature(permit, address(framework), 0xB0B, DOMAIN_SEPARATOR);

        vm.prank(bob);
        framework.joinAgreement(agreementId, resolver, permit, signature);
    }

    function bobDisputesAgreement(bytes32 agreementId) internal {
        vm.startPrank(bob);
        framework.disputeAgreement(agreementId);
        vm.stopPrank();
    }

    function aliceJoinsAgreement(bytes32 agreementId) internal {
        (
            CriteriaResolver memory resolver,
            ISignatureTransfer.PermitBatchTransferFrom memory permit,
            bytes memory signature
        ) = getAliceJoinParams();

        vm.prank(alice);
        framework.joinAgreement(agreementId, resolver, permit, signature);
    }

    function aliceExpectsErrorWhenJoining(bytes32 agreementId, bytes4 error) internal {
        (
            CriteriaResolver memory resolver,
            ISignatureTransfer.PermitBatchTransferFrom memory permit,
            bytes memory signature
        ) = getAliceJoinParams();

        vm.prank(alice);
        vm.expectRevert(error);
        framework.joinAgreement(agreementId, resolver, permit, signature);
    }

    function aliceExpectsErrorWhenJoining(bytes32 agreementId, CriteriaResolver memory resolver, bytes4 error) internal {
        (
            ,
            ISignatureTransfer.PermitBatchTransferFrom memory permit,
            bytes memory signature
        ) = getAliceJoinParams();

        vm.prank(alice);
        vm.expectRevert(error);
        framework.joinAgreement(agreementId, resolver, permit, signature);
    }

    function aliceExpectsErrorWhenFinalizing(bytes32 agreementId, bytes4 error) internal {
        vm.prank(alice);
        vm.expectRevert(error);
        framework.finalizeAgreement(agreementId);
    }

    function getAliceJoinParams() internal view returns (
       CriteriaResolver memory resolver,
       ISignatureTransfer.PermitBatchTransferFrom memory permit,
       bytes memory signature
    ){
        resolver = CriteriaResolver(alice, aliceStake, proofs[alice]);

        TokenPair[] memory tokenPairs = getJoinTokenPairs(aliceStake);
        permit = defaultERC20PermitMultiple(tokenPairs, 0);
        signature = getPermitBatchTransferSignature(permit, address(framework), 0xA11CE, DOMAIN_SEPARATOR);
    }

    function getJoinTokenPairs(uint256 collateral) internal view returns (TokenPair[] memory tokenPairs){
        tokenPairs = new TokenPair[](2);
        tokenPairs[0] = TokenPair(address(tokenB), deposits.amount);
        tokenPairs[1] = TokenPair(address(tokenA), collateral);
    }

    function getValidSettlement() internal view returns(PositionParams[] memory settlement) {
        settlement = new PositionParams[](2);
        settlement[0] = PositionParams(bob, bobStake + aliceStake);
        settlement[1] = PositionParams(alice, 0);
    }

    function setDefaultAgreementParams() internal {
        setDefaultCriteria();
        params = AgreementParams({
            termsHash: keccak256("Terms & Conditions"),
            criteria: criteria,
            metadataURI: "ipfs://sha256",
            token: address(tokenA)
        });
    }

    function assertEq(PositionStatus a, PositionStatus b) internal {
        if (uint256(a) != uint256(b)) {
            emit log("Error: a == b not satisfied [PositionStatus]");
            emit log_named_uint("  Expected", uint256(b));
            emit log_named_uint("    Actual", uint256(a));
            fail();
        }
    }

    function assertEq(AgreementStatus a, AgreementStatus b) internal {
        if (uint256(a) != uint256(b)) {
            emit log("Error: a == b not satisfied [AgreementStatus]");
            emit log_named_uint("  Expected", uint256(b));
            emit log_named_uint("    Actual", uint256(a));
            fail();
        }
    }

    function assertPosition(PositionData memory position, address party, uint256 balance, PositionStatus status) internal {
        assertEq(position.party, party);
        assertEq(position.balance, balance);
        assertEq(position.status, status);
    }

    function balanceOf(address token, address account) internal view returns (uint256 balance) {
        balance = ERC20(token).balanceOf(account);
    }
}
