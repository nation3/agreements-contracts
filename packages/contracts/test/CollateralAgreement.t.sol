// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";

import { IAllowanceTransfer } from "permit2/src/interfaces/IAllowanceTransfer.sol";
import { ISignatureTransfer } from "permit2/src/interfaces/ISignatureTransfer.sol";

import { SafeCast160 } from "permit2/src/libraries/SafeCast160.sol";
import { PermitHash } from "permit2/src/libraries/PermitHash.sol";
// import { Permit2 } from "permit2/src/Permit2.sol";
import { ERC20 } from "solmate/src/tokens/ERC20.sol";

import { PermitSignature, TokenPair } from "./utils/PermitSignature.sol";
import { TokenProvider } from "./utils/TokenProvider.sol";

import { OnlyArbitrator } from "../src/interfaces/IArbitrable.sol";
import { DepositConfig } from "../src/utils/interfaces/Deposits.sol";

import { CollateralAgreement } from "../src/frameworks/collateral/CollateralAgreement.sol";
import { ICollateralAgreement } from "../src/frameworks/collateral/ICollateralAgreement.sol";
import { CollateralHash } from "../src/frameworks/collateral/CollateralHash.sol";
import { IAgreementFramework } from "../src/frameworks/IAgreementFramework.sol";

import { IEIP712 } from "./utils/IERC712.sol";
import { console2 } from "forge-std/Console2.sol";

contract CollateralAgreementTest is Test, TokenProvider, PermitSignature {
    using SafeCast160 for uint256;

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
        _joinAgreementWithNParties(10);
    }

    function testDisputeAgreementByJoinedParty() public {
        bytes32 agreementId = _joinAgreementWithNParties(2);
        vm.prank(testSubjects[0]);
        framework.disputeAgreement(agreementId);
    }

    function testRevertWhenDisputeAgreementByNotJoinedParty() public {
        bytes32 agreementId = _joinAgreementWithNParties(2);
        vm.prank(testSubjects[2]);
        vm.expectRevert(IAgreementFramework.PartyNotJoined.selector);
        framework.disputeAgreement(agreementId);
    }

    function testRevertWhenDisputeAgreementByTwoJoinedParties() public {
        bytes32 agreementId = _joinAgreementWithNParties(2);
        vm.prank(testSubjects[0]);
        framework.disputeAgreement(agreementId);
        vm.prank(testSubjects[1]);
        vm.expectRevert(IAgreementFramework.AgreementNotOngoing.selector);
        framework.disputeAgreement(agreementId);
    }

    function testFinalizeAgreement() public {
        bytes32 agreementId = _joinAgreementWithNParties(2);
        _finalizeAgreementWithNParties(2, agreementId, false);
    }

    function testRevertWhenPartialFinalizeAgreement() public {
        bytes32 agreementId = _joinAgreementWithNParties(2);
        vm.expectRevert(ICollateralAgreement.InvalidPartySetupLength.selector);
        _finalizeAgreementWithNParties(1, agreementId, false);
    }

    function _joinAgreementWithNParties(
        uint256 numberOfParties
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
                0,
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
                    0,
                    block.timestamp + 1 days,
                    testSubjectKeys[i],
                    COLLATERAL_DOMAIN_SEPARATOR
                ),
                nonce: 0,
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

    // MOVE THIS TO ANOTHER FILE

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
