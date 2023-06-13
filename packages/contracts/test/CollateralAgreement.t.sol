// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/Console2.sol";

import { IAllowanceTransfer } from "permit2/src/interfaces/IAllowanceTransfer.sol";
import { ISignatureTransfer } from "permit2/src/interfaces/ISignatureTransfer.sol";
import { PermitHash } from "permit2/src/libraries/PermitHash.sol";

import { ERC20 } from "solmate/src/tokens/ERC20.sol";
import { IEIP712 } from "./utils/IEIP712.sol";

import { PermitSignature, TokenPair } from "./utils/PermitSignature.sol";
import { TokenProvider } from "./utils/TokenProvider.sol";

import { IArbitrable } from "../src/arbitrator/IArbitrable.sol";
import { DepositConfig } from "../src/arbitrator/ArbitratorTypes.sol";

import { CollateralAgreement } from "../src/frameworks/collateral/CollateralAgreement.sol";
import { ICollateralAgreement } from "../src/frameworks/collateral/ICollateralAgreement.sol";
import { CollateralHash } from "../src/frameworks/collateral/CollateralHash.sol";
import { IAgreementFramework } from "../src/frameworks/IAgreementFramework.sol";
import { EIP712WithNonces } from "../src/utils/EIP712WithNonces.sol";

contract CollateralAgreementTest is Test, TokenProvider, PermitSignature {
    CollateralAgreement framework;

    bytes32 PERMIT2_DOMAIN_SEPARATOR;
    bytes32 COLLATERAL_DOMAIN_SEPARATOR;

    address arbitrator = address(0xB055);

    DepositConfig deposits;

    function setUp() public {
        initializeERC20Tokens();

        deposits = DepositConfig(address(tokenB), 1e17, arbitrator);

        framework = new CollateralAgreement(ISignatureTransfer(permit2), address(this));

        framework.setUp(arbitrator, deposits);

        PERMIT2_DOMAIN_SEPARATOR = IEIP712(permit2).DOMAIN_SEPARATOR();
        COLLATERAL_DOMAIN_SEPARATOR = framework.DOMAIN_SEPARATOR();
    }

    function testJoinWithSignatures() public {
        bytes32 agreementId = _joinAgreementWithNParties(10, 0);

        ICollateralAgreement.AgreementData memory agreement = framework.agreementData(agreementId);

        assertEq(agreement.termsHash, keccak256("terms"));
        assertEq(agreement.token, address(tokenA));
        assertEq(agreement.deposit, 1e17);
        assertEq(agreement.totalCollateral, 1e17 * 10);
        assertEq(agreement.status, keccak256(abi.encodePacked("AGREEMENT_STATUS_ONGOING")));
        assertEq(agreement.numParties, 10);

        for (uint256 i; i < 10; ++i) {
            ICollateralAgreement.Party memory party = framework.partyInAgreement(
                agreementId,
                testSubjects[i]
            );

            assertEq(party.collateral, 1e17);
            assertEq(party.status, keccak256(abi.encodePacked("PARTY_STATUS_JOINED")));
        }
    }

    // AGREEMENT DISPUTES //

    function testDisputeAgreementByJoinedParty() public {
        bytes32 agreementId = _joinAgreementWithNParties(2, 0);
        vm.prank(testSubjects[0]);
        framework.disputeAgreement(agreementId);
    }

    function testRevertWhenDisputeAgreementByNotJoinedParty() public {
        bytes32 agreementId = _joinAgreementWithNParties(2, 0);
        vm.prank(testSubjects[2]);
        vm.expectRevert(IAgreementFramework.PartyNotJoined.selector);
        framework.disputeAgreement(agreementId);
    }

    function testRevertWhenDisputeAgreementByTwoJoinedParties() public {
        bytes32 agreementId = _joinAgreementWithNParties(2, 0);
        vm.prank(testSubjects[0]);
        framework.disputeAgreement(agreementId);
        vm.prank(testSubjects[1]);
        vm.expectRevert(IAgreementFramework.AgreementNotOngoing.selector);
        framework.disputeAgreement(agreementId);
    }

    // AGREEMENT FINALIZATIONS //

    function testFinalizeAgreement() public {
        bytes32 agreementId = _joinAgreementWithNParties(2, 0);
        _finalizeAgreementWithNParties(2, agreementId, 1, false);
    }

    function testRevertWhenPartialFinalizeAgreement() public {
        bytes32 agreementId = _joinAgreementWithNParties(2, 0);
        vm.expectRevert(ICollateralAgreement.InvalidPartySetupLength.selector);
        _finalizeAgreementWithNParties(1, agreementId, 1, false);
    }

    // AGREEMENT RELEASE //

    function testReleaseFunds() public {
        bytes32 agreementId = _joinAgreementWithNParties(2, 0);
        _finalizeAgreementWithNParties(2, agreementId, 1, false);
        vm.prank(testSubjects[0]);
        framework.release(agreementId);
    }

    function testRevertWhenDoubleRelease() public {
        bytes32 agreementId = _joinAgreementWithNParties(2, 0);
        _finalizeAgreementWithNParties(2, agreementId, 1, false);
        vm.startPrank(testSubjects[0]);
        framework.release(agreementId);
        vm.expectRevert(IAgreementFramework.PartyNotJoined.selector);
        framework.release(agreementId);
    }

    function testRevertWhenFinalizationReleaseAndThenRelease() public {
        bytes32 agreementId = _joinAgreementWithNParties(2, 0);
        _finalizeAgreementWithNParties(2, agreementId, 1, true);
        vm.prank(testSubjects[0]);
        vm.expectRevert(IAgreementFramework.PartyNotJoined.selector);
        framework.release(agreementId);
    }

    function testRevertWhenReleaseByNotJoinedParty() public {
        bytes32 agreementId = _joinAgreementWithNParties(2, 0);
        _finalizeAgreementWithNParties(2, agreementId, 1, false);
        vm.prank(testSubjects[3]);
        vm.expectRevert(IAgreementFramework.PartyNotJoined.selector);
        framework.release(agreementId);
    }

    function testRevertWhenReleaseOnDisputedAgreement() public {
        bytes32 agreementId = _joinAgreementWithNParties(2, 0);
        vm.prank(testSubjects[1]);
        framework.disputeAgreement(agreementId);
        vm.expectRevert(IAgreementFramework.AgreementNotFinalized.selector);
        vm.prank(testSubjects[0]);
        framework.release(agreementId);
    }

    // AGREEMENT SETTLEMENT //

    function testSettlement() public {
        bytes32 agreementId = _joinAgreementWithNParties(2, 0);

        vm.prank(testSubjects[0]);
        framework.disputeAgreement(agreementId);

        ICollateralAgreement.PartySetup[]
            memory partySetups = new ICollateralAgreement.PartySetup[](2);
        partySetups[0] = ICollateralAgreement.PartySetup(testSubjects[0], 1e17);
        partySetups[1] = ICollateralAgreement.PartySetup(testSubjects[1], 1e17);

        vm.prank(arbitrator);
        framework.settle(agreementId, abi.encode(partySetups));
    }

    function testSettlementWithAllCollateralToOneParty() public {
        bytes32 agreementId = _joinAgreementWithNParties(2, 0);

        vm.prank(testSubjects[0]);
        framework.disputeAgreement(agreementId);

        ICollateralAgreement.PartySetup[]
            memory partySetups = new ICollateralAgreement.PartySetup[](2);
        partySetups[0] = ICollateralAgreement.PartySetup(testSubjects[0], 1e17 * 2);
        partySetups[1] = ICollateralAgreement.PartySetup(testSubjects[1], 0);

        vm.prank(arbitrator);
        framework.settle(agreementId, abi.encode(partySetups));
    }

    function testSettlementWithMixedCollateralSetup() public {
        bytes32 agreementId = _joinAgreementWithNParties(2, 0);

        vm.prank(testSubjects[0]);
        framework.disputeAgreement(agreementId);

        ICollateralAgreement.PartySetup[]
            memory partySetups = new ICollateralAgreement.PartySetup[](2);
        partySetups[0] = ICollateralAgreement.PartySetup(testSubjects[0], 1e17 - 1e15);
        partySetups[1] = ICollateralAgreement.PartySetup(testSubjects[1], 1e17 + 1e15);

        vm.prank(arbitrator);
        framework.settle(agreementId, abi.encode(partySetups));
    }

    function testSettlementWithArbitrationFee() public {
        bytes32 agreementId = _joinAgreementWithNParties(2, 0);

        vm.prank(testSubjects[1]);
        framework.disputeAgreement(agreementId);

        ICollateralAgreement.PartySetup[]
            memory partySetups = new ICollateralAgreement.PartySetup[](3);
        partySetups[0] = ICollateralAgreement.PartySetup(arbitrator, 1e17); // arbitrator
        partySetups[1] = ICollateralAgreement.PartySetup(testSubjects[0], 1e17);
        partySetups[2] = ICollateralAgreement.PartySetup(testSubjects[1], 0);

        vm.prank(arbitrator);
        framework.settle(agreementId, abi.encode(partySetups));
    }

    function testSettlementWithMaxArbitrationFee() public {
        bytes32 agreementId = _joinAgreementWithNParties(2, 0);

        vm.prank(testSubjects[1]);
        framework.disputeAgreement(agreementId);

        ICollateralAgreement.PartySetup[]
            memory partySetups = new ICollateralAgreement.PartySetup[](3);
        partySetups[0] = ICollateralAgreement.PartySetup(arbitrator, 1e17 * 2); // arbitrator
        partySetups[1] = ICollateralAgreement.PartySetup(testSubjects[0], 0);
        partySetups[2] = ICollateralAgreement.PartySetup(testSubjects[1], 0);

        vm.prank(arbitrator);
        framework.settle(agreementId, abi.encode(partySetups));
    }

    function testRevertWhenNotArbitrator() public {
        bytes32 agreementId = _joinAgreementWithNParties(2, 0);
        vm.prank(testSubjects[0]);
        framework.disputeAgreement(agreementId);
        vm.expectRevert(IArbitrable.NotArbitrator.selector);
        framework.settle(agreementId, new bytes(0));
    }

    function testRevertWhenSettlementIsEmtpy() public {
        bytes32 agreementId = _joinAgreementWithNParties(3, 0);
        vm.prank(testSubjects[0]);
        framework.disputeAgreement(agreementId);

        ICollateralAgreement.PartySetup[]
            memory partySetups = new ICollateralAgreement.PartySetup[](2);
        partySetups[0] = ICollateralAgreement.PartySetup(testSubjects[0], 1e17);
        partySetups[1] = ICollateralAgreement.PartySetup(testSubjects[1], 1e17);

        vm.prank(arbitrator);
        vm.expectRevert(bytes("")); // Runtime EVM error
        framework.settle(agreementId, new bytes(0));
    }

    function testRevertWhenSettlementOnNonDisputedAgreement() public {
        bytes32 agreementId = _joinAgreementWithNParties(2, 0);
        ICollateralAgreement.PartySetup[]
            memory partySetups = new ICollateralAgreement.PartySetup[](2);
        partySetups[0] = ICollateralAgreement.PartySetup(testSubjects[0], 1e17);
        partySetups[1] = ICollateralAgreement.PartySetup(testSubjects[1], 1e17);

        vm.prank(arbitrator);
        vm.expectRevert(IAgreementFramework.AgreementNotDisputed.selector);
        framework.settle(agreementId, abi.encode(partySetups));
    }

    function testRevertWhenSettlementOnFinalizedAgreement() public {
        bytes32 agreementId = _joinAgreementWithNParties(3, 0);
        ICollateralAgreement.PartySetup[]
            memory partySetups = new ICollateralAgreement.PartySetup[](3);
        partySetups[0] = ICollateralAgreement.PartySetup(testSubjects[0], 1e17);
        partySetups[1] = ICollateralAgreement.PartySetup(testSubjects[1], 1e17);
        partySetups[2] = ICollateralAgreement.PartySetup(testSubjects[2], 1e17);

        _finalizeAgreementWithNParties(3, agreementId, 1, false);

        vm.prank(arbitrator);
        vm.expectRevert(IAgreementFramework.AgreementNotDisputed.selector);
        framework.settle(agreementId, abi.encode(partySetups));
    }

    function testRevertWhenSettlementLengthIsLower() public {
        bytes32 agreementId = _joinAgreementWithNParties(3, 0);
        vm.prank(testSubjects[0]);
        framework.disputeAgreement(agreementId);

        ICollateralAgreement.PartySetup[]
            memory partySetups = new ICollateralAgreement.PartySetup[](2);
        partySetups[0] = ICollateralAgreement.PartySetup(testSubjects[0], 1e17);
        partySetups[1] = ICollateralAgreement.PartySetup(testSubjects[1], 1e17);

        vm.prank(arbitrator);
        vm.expectRevert(IArbitrable.InvalidSettlement.selector);
        framework.settle(agreementId, abi.encode(partySetups));
    }

    function testRevertWhenSettlementLengthIsHigher() public {
        bytes32 agreementId = _joinAgreementWithNParties(3, 0);
        vm.prank(testSubjects[0]);
        framework.disputeAgreement(agreementId);

        ICollateralAgreement.PartySetup[]
            memory partySetups = new ICollateralAgreement.PartySetup[](4);
        partySetups[0] = ICollateralAgreement.PartySetup(testSubjects[0], 1e17);
        partySetups[1] = ICollateralAgreement.PartySetup(testSubjects[1], 1e17);
        partySetups[2] = ICollateralAgreement.PartySetup(testSubjects[2], 1e17);
        partySetups[3] = ICollateralAgreement.PartySetup(testSubjects[3], 1e17);

        vm.prank(arbitrator);
        vm.expectRevert(IArbitrable.InvalidSettlement.selector);
        framework.settle(agreementId, abi.encode(partySetups));
    }

    function testRevertWhenSettlementSetupIsHigherThanTotalCollateral() public {
        bytes32 agreementId = _joinAgreementWithNParties(3, 0);
        vm.prank(testSubjects[0]);
        framework.disputeAgreement(agreementId);

        ICollateralAgreement.PartySetup[]
            memory partySetups = new ICollateralAgreement.PartySetup[](3);
        partySetups[0] = ICollateralAgreement.PartySetup(testSubjects[0], 1e17);
        partySetups[1] = ICollateralAgreement.PartySetup(testSubjects[1], 1e17);
        partySetups[2] = ICollateralAgreement.PartySetup(testSubjects[2], 1e17 + 1); // Higher

        vm.prank(arbitrator);
        vm.expectRevert(IArbitrable.InvalidSettlement.selector);
        framework.settle(agreementId, abi.encode(partySetups));
    }

    function testRevertWhenSettlementSetupIsLowerThanTotalCollateral() public {
        bytes32 agreementId = _joinAgreementWithNParties(3, 0);
        vm.prank(testSubjects[0]);
        framework.disputeAgreement(agreementId);

        ICollateralAgreement.PartySetup[]
            memory partySetups = new ICollateralAgreement.PartySetup[](3);
        partySetups[0] = ICollateralAgreement.PartySetup(testSubjects[0], 1e17 - 1); // Lower
        partySetups[1] = ICollateralAgreement.PartySetup(testSubjects[1], 1e17);
        partySetups[2] = ICollateralAgreement.PartySetup(testSubjects[2], 1e17);

        vm.prank(arbitrator);
        vm.expectRevert(IArbitrable.InvalidSettlement.selector);
        framework.settle(agreementId, abi.encode(partySetups));
    }

    function testRevertWhenSettlementFeeIsNotSetToArbitrator() public {
        bytes32 agreementId = _joinAgreementWithNParties(2, 0);

        vm.prank(testSubjects[1]);
        framework.disputeAgreement(agreementId);

        ICollateralAgreement.PartySetup[]
            memory partySetups = new ICollateralAgreement.PartySetup[](3);
        partySetups[0] = ICollateralAgreement.PartySetup(address(0x1111), 1e17); // arbitrator
        partySetups[1] = ICollateralAgreement.PartySetup(testSubjects[0], 1e17);
        partySetups[2] = ICollateralAgreement.PartySetup(testSubjects[1], 0);

        vm.prank(arbitrator);
        vm.expectRevert(IArbitrable.InvalidSettlement.selector);
        framework.settle(agreementId, abi.encode(partySetups));
    }

    function testRevertWhenSettlementFeeIsInTheWrongOrder() public {
        bytes32 agreementId = _joinAgreementWithNParties(2, 0);

        vm.prank(testSubjects[1]);
        framework.disputeAgreement(agreementId);

        ICollateralAgreement.PartySetup[]
            memory partySetups = new ICollateralAgreement.PartySetup[](3);
        partySetups[0] = ICollateralAgreement.PartySetup(testSubjects[0], 1e17);
        partySetups[1] = ICollateralAgreement.PartySetup(testSubjects[1], 0);
        partySetups[2] = ICollateralAgreement.PartySetup(arbitrator, 1e17);

        vm.prank(arbitrator);
        vm.expectRevert(IArbitrable.InvalidSettlement.selector);
        framework.settle(agreementId, abi.encode(partySetups));
    }

    function testRevertWhenSettlementFeeIsHigher() public {
        bytes32 agreementId = _joinAgreementWithNParties(2, 0);

        vm.prank(testSubjects[1]);
        framework.disputeAgreement(agreementId);

        ICollateralAgreement.PartySetup[]
            memory partySetups = new ICollateralAgreement.PartySetup[](3);
        partySetups[0] = ICollateralAgreement.PartySetup(arbitrator, 1e17 + 1);
        partySetups[1] = ICollateralAgreement.PartySetup(testSubjects[0], 1e17);
        partySetups[2] = ICollateralAgreement.PartySetup(testSubjects[1], 0);

        vm.prank(arbitrator);
        vm.expectRevert(IArbitrable.InvalidSettlement.selector);
        framework.settle(agreementId, abi.encode(partySetups));
    }

    // EIP712 SIGNATURES //

    function testUnorderedNonce() public {
        bytes32 agreementId = _joinAgreementWithNParties(2, 4);
        _finalizeAgreementWithNParties(2, agreementId, 0, false);
    }

    function testRevertOnRevokedNonce() public {
        bytes32 agreementId = _joinAgreementWithNParties(2, 0);

        vm.prank(testSubjects[0]);
        framework.invalidateUnorderedNonces(0, 1 << 4);
        vm.expectRevert(EIP712WithNonces.InvalidNonce.selector);
        _finalizeAgreementWithNParties(2, agreementId, 4, true);
    }

    function testRevertWhenNonceIsUsedTwice() public {
        bytes32 agreementId = _joinAgreementWithNParties(2, 0);
        vm.expectRevert(EIP712WithNonces.InvalidNonce.selector);
        _finalizeAgreementWithNParties(2, agreementId, 0, false);
    }

    // INTERNAL FUNCTIONS //

    function _joinAgreementWithNParties(
        uint256 numberOfParties,
        uint256 nonce
    ) internal returns (bytes32 agreementId) {
        ICollateralAgreement.PartySetup[] memory parties = new ICollateralAgreement.PartySetup[](
            numberOfParties
        );

        for (uint i; i < numberOfParties; ++i) {
            parties[i] = ICollateralAgreement.PartySetup(testSubjects[i], 1e17);
        }

        ICollateralAgreement.AgreementSetup memory agreementSetup = ICollateralAgreement
            .AgreementSetup(keccak256("terms"), address(tokenA), bytes32(0), "URI", parties);

        ICollateralAgreement.PartyPermit[]
            memory joinPermits = new ICollateralAgreement.PartyPermit[](numberOfParties);

        ISignatureTransfer.PermitBatchTransferFrom[]
            memory transferPermits = new ISignatureTransfer.PermitBatchTransferFrom[](
                numberOfParties
            );
        ICollateralAgreement.Permit2SignatureTransfer[]
            memory permit2Signatures = new ICollateralAgreement.Permit2SignatureTransfer[](
                numberOfParties
            );

        bytes[] memory transferSignatures = new bytes[](numberOfParties);

        TokenPair[] memory tokenPairs = new TokenPair[](2);
        tokenPairs[0] = TokenPair(address(tokenB), deposits.amount);
        tokenPairs[1] = TokenPair(address(tokenA), 1 * 1e17);

        for (uint i; i < numberOfParties; ++i) {
            joinPermits[i] = _getPartyPermitForAgreementSetup(
                agreementSetup,
                nonce,
                block.timestamp + 1 days,
                testSubjectKeys[i]
            );

            transferPermits[i] = defaultERC20PermitMultiple(tokenPairs, 0);

            transferSignatures[i] = getPermitBatchTransferSignature(
                transferPermits[i],
                address(framework),
                testSubjectKeys[i],
                PERMIT2_DOMAIN_SEPARATOR
            );

            permit2Signatures[i] = ICollateralAgreement.Permit2SignatureTransfer({
                transferPermit: transferPermits[i],
                transferSignature: transferSignatures[i]
            });
        }

        agreementId = framework.createWithSignatures(
            agreementSetup,
            joinPermits,
            permit2Signatures
        );
    }

    function _finalizeAgreementWithNParties(
        uint256 numberOfParties,
        bytes32 agreementId,
        uint256 nonce,
        bool doTransfers
    ) internal {
        ICollateralAgreement.PartySetup[]
            memory partySetups = new ICollateralAgreement.PartySetup[](numberOfParties);

        ICollateralAgreement.PartyPermit[]
            memory partySignatures = new ICollateralAgreement.PartyPermit[](numberOfParties);

        for (uint256 i; i < numberOfParties; ++i) {
            partySetups[i] = ICollateralAgreement.PartySetup(testSubjects[i], 0);

            partySignatures[i] = ICollateralAgreement.PartyPermit({
                signature: _getPartySignatureForUpdateParty(
                    partySetups[i],
                    keccak256(abi.encodePacked("PARTY_STATUS_FINALIZED")),
                    nonce,
                    block.timestamp + 1 days,
                    testSubjectKeys[i],
                    COLLATERAL_DOMAIN_SEPARATOR
                ),
                nonce: nonce,
                deadline: block.timestamp + 1 days
            });
        }

        framework.finalizeAgreement(agreementId, partySetups, partySignatures, doTransfers);
    }

    function _getPartySignatureForUpdateParty(
        ICollateralAgreement.PartySetup memory partySetup,
        bytes32 status,
        uint256 nonce,
        uint256 deadline,
        uint256 privateKey,
        bytes32 domainSeparator
    ) internal pure returns (bytes memory sig) {
        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(
                        CollateralHash.UPDATE_PARTY_TYPEHASH,
                        keccak256(
                            abi.encode(
                                CollateralHash.PARTY_SETUP_TYPEHASH,
                                partySetup.signer,
                                partySetup.collateral
                            )
                        ),
                        status,
                        nonce,
                        deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        return bytes.concat(r, s, bytes1(v));
    }

    function _getPartyPermitForAgreementSetup(
        ICollateralAgreement.AgreementSetup memory agreementSetup,
        uint256 nonce,
        uint256 deadline,
        uint256 privateKey
    ) internal view returns (ICollateralAgreement.PartyPermit memory) {
        return
            ICollateralAgreement.PartyPermit({
                nonce: nonce,
                deadline: deadline,
                signature: _getPartySignatureForAgreementSetup(
                    agreementSetup,
                    nonce,
                    deadline,
                    privateKey,
                    COLLATERAL_DOMAIN_SEPARATOR
                )
            });
    }

    function _getPartySignatureForAgreementSetup(
        ICollateralAgreement.AgreementSetup memory agreementSetup,
        uint256 nonce,
        uint256 deadline,
        uint256 privateKey,
        bytes32 domainSeparator
    ) internal pure returns (bytes memory sig) {
        uint256 numParties = agreementSetup.parties.length;
        bytes32[] memory partyHashes = new bytes32[](numParties);

        for (uint256 i = 0; i < numParties; ++i) {
            partyHashes[i] = keccak256(
                abi.encode(
                    CollateralHash.PARTY_SETUP_TYPEHASH,
                    agreementSetup.parties[i].signer,
                    agreementSetup.parties[i].collateral
                )
            );
        }

        bytes32 agreementHash = keccak256(
            abi.encode(
                CollateralHash.AGREEMENT_SETUP_TYPEHASH,
                agreementSetup.termsHash,
                agreementSetup.token,
                agreementSetup.salt,
                keccak256(bytes(agreementSetup.metadataURI)),
                keccak256(abi.encodePacked(partyHashes))
            )
        );

        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(CollateralHash.JOIN_PERMIT_TYPEHASH, agreementHash, nonce, deadline)
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        return bytes.concat(r, s, bytes1(v));
    }
}
