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
        ICollateralAgreement.PartySetup[] memory parties = new ICollateralAgreement.PartySetup[](3);

        parties[0] = ICollateralAgreement.PartySetup(bob, 1e17);
        parties[1] = ICollateralAgreement.PartySetup(alice, 1e17);
        parties[2] = ICollateralAgreement.PartySetup(cafe, 1e17);

        ICollateralAgreement.AgreementSetup memory agreementSetup = ICollateralAgreement
            .AgreementSetup(keccak256("terms"), address(tokenA), bytes32(0), "URI", parties);

        // Joining parties Signatures
        ICollateralAgreement.PartyPermit[]
            memory joinPermits = new ICollateralAgreement.PartyPermit[](3);

        joinPermits[0] = _getPartyPermitForAgreementSetup(
            agreementSetup,
            0,
            block.timestamp + 1 days,
            0xB0B
        );
        joinPermits[1] = _getPartyPermitForAgreementSetup(
            agreementSetup,
            1,
            block.timestamp + 1 days,
            0xA11CE
        );
        joinPermits[2] = _getPartyPermitForAgreementSetup(
            agreementSetup,
            2,
            block.timestamp + 1 days,
            0xCAFE
        );

        // Permit2 signature and transfer
        TokenPair[] memory tokenPairs = new TokenPair[](2);
        tokenPairs[0] = TokenPair(address(tokenB), deposits.amount);
        tokenPairs[1] = TokenPair(address(tokenA), bobStake);

        ISignatureTransfer.PermitBatchTransferFrom[]
            memory transferPermits = new ISignatureTransfer.PermitBatchTransferFrom[](3);

        transferPermits[0] = defaultERC20PermitMultiple(tokenPairs, 0);
        transferPermits[1] = defaultERC20PermitMultiple(tokenPairs, 1);
        transferPermits[2] = defaultERC20PermitMultiple(tokenPairs, 2);

        bytes[] memory transferSignatures = new bytes[](3);

        transferSignatures[0] = getPermitBatchTransferSignature(
            transferPermits[0],
            address(framework),
            0xB0B,
            PERMIT2_DOMAIN_SEPARATOR
        );
        transferSignatures[1] = getPermitBatchTransferSignature(
            transferPermits[1],
            address(framework),
            0xA11CE,
            PERMIT2_DOMAIN_SEPARATOR
        );
        transferSignatures[2] = getPermitBatchTransferSignature(
            transferPermits[2],
            address(framework),
            0xCAFE,
            PERMIT2_DOMAIN_SEPARATOR
        );

        framework.createWithSignatures(
            agreementSetup,
            joinPermits,
            transferPermits,
            transferSignatures
        );
    }

    // MOVE THIS TO ANOTHER FILE

    /* function _createPositionSignature(
        ICollateralAgreement.AgreementSetup memory agreementSetup,
        uint256 privateKey
    ) public returns (ICollateralAgreement.PartySetup memory) {
        return
            ICollateralAgreement.Position({
                nonce: 0,
                deadline: block.timestamp + 1 days,
                signature: _getPositionSignatureForAgreementSetup(
                    agreementSetup,
                    0,
                    block.timestamp + 1 days,
                    privateKey,
                    COLLATERAL_DOMAIN_SEPARATOR
                )
            });
    } */

    function _getPartyPermitForAgreementSetup(
        ICollateralAgreement.AgreementSetup memory agreementSetup,
        uint256 nonce,
        uint256 deadline,
        uint256 privateKey
    ) public returns (ICollateralAgreement.PartyPermit memory) {
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
