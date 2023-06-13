// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";

import { N3Vault } from "../src/vault/N3Vault.sol";
import { IN3Vault } from "../src/vault/IN3Vault.sol";
import { N3VaultHash } from "../src/vault/N3VaultHash.sol";

import { ISignatureTransfer } from "permit2/src/interfaces/ISignatureTransfer.sol";

import { TokenProvider } from "./utils/TokenProvider.sol";
import { PermitSignature, TokenPair } from "./utils/PermitSignature.sol";
import { IEIP712 } from "./utils/IERC712.sol";

// TODO: Come back to do more tests
contract N3VaultTest is Test, TokenProvider, PermitSignature {
    bytes32 PERMIT2_DOMAIN_SEPARATOR;
    bytes32 VAULT_DOMAIN_SEPARATOR;

    N3Vault vault;

    function setUp() public {
        initializeERC20Tokens();

        vault = new N3Vault(ISignatureTransfer(permit2));

        PERMIT2_DOMAIN_SEPARATOR = IEIP712(permit2).DOMAIN_SEPARATOR();
        VAULT_DOMAIN_SEPARATOR = vault.DOMAIN_SEPARATOR();
    }

    function testOneTokenDeposit() public {
        bytes32 escrowId = bytes32("xx");

        _deposit(0, _toVault(1), escrowId, _createTokenPairForDeposit(1));
        assertEq(vault.balanceOfOnEscrow(testSubjects[0], address(tokenA), escrowId), 1e17);
    }

    function testMultipleTokenDeposit() public {
        bytes32 escrowId = bytes32("xx");

        _deposit(0, _toVault(2), escrowId, _createTokenPairForDeposit(2));

        assertEq(vault.balanceOfOnEscrow(testSubjects[0], address(tokenA), escrowId), 1e17);
        assertEq(vault.balanceOfOnEscrow(testSubjects[0], address(tokenB), escrowId), 1e17);
    }

    function testBalanceNotAwardedWhenToIsNotVaultSingle() public {
        bytes32 escrowId = bytes32("xx");

        address[] memory customTo = new address[](1);
        customTo[0] = address(0xDEAD);

        _deposit(0, customTo, escrowId, _createTokenPairForDeposit(1));

        // balance not awarded
        assertEq(vault.balanceOfOnEscrow(testSubjects[0], address(tokenA), escrowId), 0);
        // but transfer was successful
        assertEq(tokenA.balanceOf(address(0xDEAD)), 1e17);
    }

    function testBalanceNotAwardedWhenToIsNotVaultMultiple() public {
        bytes32 escrowId = bytes32("xx");

        address[] memory customTo = new address[](2);
        customTo[0] = address(0xDEAD);
        customTo[1] = address(vault);

        _deposit(0, customTo, escrowId, _createTokenPairForDeposit(2));

        assertEq(vault.balanceOfOnEscrow(testSubjects[0], address(tokenB), escrowId), 1e17);
        // balance not awarded
        assertEq(vault.balanceOfOnEscrow(testSubjects[0], address(tokenA), escrowId), 0);
        // but transfer was successful
        assertEq(tokenA.balanceOf(address(0xDEAD)), 1e17);
        // for only TokenA
        assertEq(tokenB.balanceOf(address(0xDEAD)), 0);
    }

    function testActivateEscrow() public {
        address[] memory tokens = new address[](1);
        tokens[0] = address(tokenA);

        IN3Vault.EscrowPermit memory escrowPermit = IN3Vault.EscrowPermit({
            escrowId: bytes32("xx"),
            tokens: tokens,
            locker: address(0xC011A735A11),
            signer: testSubjects[0],
            nonce: 0,
            deadline: block.timestamp + 100
        });

        bytes memory escrowSignature = _getEscrowPermitSignature(
            escrowPermit,
            testSubjectKeys[0],
            VAULT_DOMAIN_SEPARATOR
        );

        bytes32 escrowId = bytes32("xx");

        _deposit(0, _toVault(1), escrowId, _createTokenPairForDeposit(1));

        vm.prank(address(0xC011A735A11));
        vault.activateEscrow(escrowPermit, 1e17, escrowId, escrowSignature);
    }

    function testRevertOnActivateEscrowWhenInsufficientEscrowBalance() public {
        address[] memory tokens = new address[](1);
        tokens[0] = address(tokenA);

        IN3Vault.EscrowPermit memory escrowPermit = IN3Vault.EscrowPermit({
            escrowId: bytes32("xx"),
            tokens: tokens,
            locker: address(0xC011A735A11),
            signer: testSubjects[0],
            nonce: 0,
            deadline: block.timestamp + 100
        });

        bytes memory escrowSignature = _getEscrowPermitSignature(
            escrowPermit,
            testSubjectKeys[0],
            VAULT_DOMAIN_SEPARATOR
        );

        bytes32 escrowId = bytes32("xx");

        // no deposit.

        vm.prank(address(0xC011A735A11));

        vm.expectRevert(IN3Vault.InsufficientEscrowBalance.selector);
        vault.activateEscrow(escrowPermit, 1e17, escrowId, escrowSignature);
    }

    function _deposit(
        uint256 subject,
        address[] memory to,
        bytes32 escrowId,
        IN3Vault.TokenAmount[] memory tokenAmounts
    ) internal {
        uint256 numTokens = tokenAmounts.length;

        ISignatureTransfer.TokenPermissions[]
            memory tokenPermissions = new ISignatureTransfer.TokenPermissions[](numTokens);

        ISignatureTransfer.SignatureTransferDetails[]
            memory transferDetails = new ISignatureTransfer.SignatureTransferDetails[](numTokens);

        for (uint256 i; i < numTokens; ++i) {
            tokenPermissions[i] = ISignatureTransfer.TokenPermissions({
                token: tokenAmounts[i].token,
                amount: tokenAmounts[i].amount
            });

            transferDetails[i] = ISignatureTransfer.SignatureTransferDetails({
                to: address(to[i]),
                requestedAmount: tokenAmounts[i].amount
            });
        }

        ISignatureTransfer.PermitBatchTransferFrom memory transferPermit = ISignatureTransfer
            .PermitBatchTransferFrom({
                permitted: tokenPermissions,
                nonce: 0,
                deadline: block.timestamp + 100
            });

        IN3Vault.Permit2Transfer memory permit2Transfer = IN3Vault.Permit2Transfer({
            transferDetails: transferDetails,
            permit: transferPermit,
            signature: getPermitBatchTransferSignature(
                transferPermit,
                address(vault),
                testSubjectKeys[subject],
                PERMIT2_DOMAIN_SEPARATOR
            )
        });

        vm.prank(testSubjects[subject]);
        vault.deposit(permit2Transfer, escrowId);
    }

    function _toVault(uint256 numberOfSends) internal view returns (address[] memory) {
        address[] memory to = new address[](numberOfSends);

        for (uint256 i; i < numberOfSends; ++i) {
            to[i] = address(vault);
        }

        return to;
    }

    function _createTokenPairForDeposit(
        uint256 numOfTokens
    ) internal view returns (IN3Vault.TokenAmount[] memory) {
        IN3Vault.TokenAmount[] memory tokenAmounts = new IN3Vault.TokenAmount[](numOfTokens);

        if (numOfTokens == 1) {
            tokenAmounts[0] = IN3Vault.TokenAmount({ token: address(tokenA), amount: 1e17 });
        } else if (numOfTokens == 2) {
            tokenAmounts[0] = IN3Vault.TokenAmount({ token: address(tokenA), amount: 1e17 });
            tokenAmounts[1] = IN3Vault.TokenAmount({ token: address(tokenB), amount: 1e17 });
        }

        return tokenAmounts;
    }

    function _getEscrowPermitSignature(
        IN3Vault.EscrowPermit memory escrowPermit,
        uint256 privateKey,
        bytes32 domainSeparator
    ) internal pure returns (bytes memory sig) {
        bytes32[] memory tokenHashes = new bytes32[](escrowPermit.tokens.length);

        for (uint256 i = 0; i < escrowPermit.tokens.length; ++i) {
            tokenHashes[i] = keccak256(abi.encode(escrowPermit.tokens[i]));
        }

        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(
                        N3VaultHash.ESCROW_PERMIT_TYPEHASH,
                        escrowPermit.escrowId,
                        keccak256(abi.encodePacked(tokenHashes)),
                        escrowPermit.locker,
                        escrowPermit.signer,
                        escrowPermit.nonce,
                        escrowPermit.deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        return bytes.concat(r, s, bytes1(v));
    }
}
