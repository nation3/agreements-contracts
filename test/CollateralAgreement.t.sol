// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import { IAllowanceTransfer } from "permit2/src/interfaces/IAllowanceTransfer.sol";
import { ISignatureTransfer } from "permit2/src/interfaces/ISignatureTransfer.sol";

import { AgreementParams, AgreementData, PositionData, PositionStatus, AgreementStatus } from "src/interfaces/Agreement.sol";
import "src/interfaces/AgreementErrors.sol";
import { InvalidCriteriaProof } from "src/libraries/CriteriaResolution.sol";

import { Test } from "forge-std/Test.sol";
import { ERC20 } from "solmate/src/tokens/ERC20.sol";
import { Permit2 } from "permit2/src/Permit2.sol";
import { SafeCast160 } from "permit2/src/libraries/SafeCast160.sol";
import { PermitHash } from "permit2/src/libraries/PermitHash.sol";

import { CriteriaProvider } from "test/utils/AgreementProvider.sol";
import { PermitSignature, TokenPair } from "test/utils/PermitSignature.sol";
import { TokenProvider } from "test/utils/TokenProvider.sol";

import { CriteriaResolver } from "src/libraries/CriteriaResolution.sol";
import { CollateralAgreementFramework, FeeConfig } from "src/frameworks/CollateralAgreement.sol";

contract CollateralAgreementFrameworkTest is Test, TokenProvider, CriteriaProvider, PermitSignature {
    using SafeCast160 for uint256;

    CollateralAgreementFramework framework;

    bytes32 DOMAIN_SEPARATOR;

    AgreementParams params;
    FeeConfig fees;

    function setUp() public {
        initializeERC20Tokens();
        DOMAIN_SEPARATOR = permit2.DOMAIN_SEPARATOR();
        fees = FeeConfig(address(tokenB), 1e17, arbitrator);

        framework = new CollateralAgreementFramework();

        framework.setUp(permit2, arbitrator, fees);

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
        assertEq(uint256(createdAgreement.status), uint256(AgreementStatus.Created));
    }

    function testJoinAgreement() public {
        bytes32 agreementId = createAgreement();
        uint256 bobBalance = ERC20(params.token).balanceOf(bob);

        bobJoinsAgreement(agreementId);

        PositionData[] memory positions = framework.agreementPositions(agreementId);

        assertEq(positions[0].party, bob);
        assertEq(positions[0].balance, bobStake);
        assertEq(uint256(positions[0].status), uint256(PositionStatus.Joined));

        assertEq(ERC20(params.token).balanceOf(bob), bobBalance - bobStake);
        assertEq(ERC20(params.token).balanceOf(address(framework)), bobStake);
        assertEq(ERC20(tokenB).balanceOf(address(framework)), fees.amount);
    }

    function testCantJoinNonExistentAgreement(bytes32 id) public {
        aliceExpectsErrorWhenJoining(id, InvalidCriteriaProof.selector);
    }

    function testCantJoinAgreementMultipleTimes() public {
        bytes32 agreementId = createAgreement();
        aliceJoinsAgreement(agreementId);

        aliceExpectsErrorWhenJoining(agreementId, PartyAlreadyJoined.selector);
    }

    function testAgreementStatusOngoing() public {
        bytes32 agreementId = createAgreement();
        bobJoinsAgreement(agreementId);

        AgreementData memory agreement = framework.agreementData(agreementId);
        assertEq(uint256(agreement.status), uint256(AgreementStatus.Ongoing));
    }

    function testFriendlyFinalization() public {
        bytes32 agreementId = createAgreement();

        bobJoinsAgreement(agreementId);
        aliceJoinsAgreement(agreementId);

        vm.prank(bob);
        framework.finalizeAgreement(agreementId);

        // Agreement continues to be ongoing
        AgreementData memory agreement = framework.agreementData(agreementId);
        assertEq(uint256(agreement.status), uint256(AgreementStatus.Ongoing));

        vm.prank(alice);
        framework.finalizeAgreement(agreementId);

        // Agreement is finalized
        agreement = framework.agreementData(agreementId);
        assertEq(uint256(agreement.status), uint256(AgreementStatus.Finalized));
    }

    function testDisputeAgreement() public {
        bytes32 agreementId = createAgreement();

        bobJoinsAgreement(agreementId);
        aliceJoinsAgreement(agreementId);

        vm.startPrank(bob);
        framework.disputeAgreement(agreementId);
        vm.stopPrank();

        AgreementData memory agreement = framework.agreementData(agreementId);
        assertEq(uint256(agreement.status), uint256(AgreementStatus.Disputed));

        PositionData[] memory positions = framework.agreementPositions(agreementId);
        assertEq(uint256(positions[0].status), uint256(PositionStatus.Disputed));
        assertEq(uint256(positions[1].status), uint256(PositionStatus.Joined));

        assertEq(ERC20(fees.token).balanceOf(arbitrator), fees.amount);
    }

    function testWithdrawFromAgreement() public {
        bytes32 agreementId = createAgreement();
        uint256 beforeBalance = ERC20(params.token).balanceOf(bob);
        uint256 beforeDeposit = ERC20(fees.token).balanceOf(bob);

        bobJoinsAgreement(agreementId);
        vm.startPrank(bob);
        framework.finalizeAgreement(agreementId);
        framework.withdrawFromAgreement(agreementId);
        vm.stopPrank();

        assertEq(ERC20(params.token).balanceOf(bob), beforeBalance);
        assertEq(ERC20(fees.token).balanceOf(bob), beforeDeposit);
    }

    /* ---------------------------------------------------------------------- */

    function createAgreement() internal returns (bytes32 agreementId) {
        setDefaultAgreementParams();
        agreementId = framework.createAgreement(params, bytes32(""));
    }

    function bobJoinsAgreement(bytes32 agreementId) internal {
        CriteriaResolver memory resolver = CriteriaResolver(bob, bobStake, proofs[bob]);

        TokenPair[] memory tokenPairs = getJoinTokenPairs(bobStake);
        ISignatureTransfer.PermitBatchTransferFrom memory permit = defaultERC20PermitMultiple(tokenPairs, 0);
        bytes memory signature = getPermitBatchTransferSignature(permit, address(framework), 0xB0B, DOMAIN_SEPARATOR);

        vm.prank(bob);
        framework.joinAgreement(agreementId, resolver, permit, signature);
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
        tokenPairs[0] = TokenPair(address(tokenB), fees.amount);
        tokenPairs[1] = TokenPair(address(tokenA), collateral);
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
}
