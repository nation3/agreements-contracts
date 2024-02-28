// // SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import { ERC20 } from "solmate/src/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/src/utils/SafeTransferLib.sol";
import { SignatureVerification } from "permit2/src/libraries/SignatureVerification.sol";
import { ISignatureTransfer } from "permit2/src/interfaces/ISignatureTransfer.sol";

import { N3VaultHash } from "./N3VaultHash.sol";

import { IN3Vault } from "./IN3Vault.sol";
import { EIP712WithNonces } from "../utils/EIP712WithNonces.sol";

contract N3Vault is IN3Vault, EIP712WithNonces {
    using SafeTransferLib for ERC20;
    using SignatureVerification for bytes;

    using N3VaultHash for IN3Vault.EscrowPermit;

    ISignatureTransfer public immutable permit2SignatureTransfer;

    mapping(bytes32 => Escrow) public escrowStatus;
    mapping(address => mapping(bytes32 => uint256)) public escrowBalance;
    // [user][token][escrowId] => amount
    mapping(address => mapping(address => mapping(bytes32 => uint256))) public userEscrowBalance;

    constructor(ISignatureTransfer permit2_) EIP712WithNonces(keccak256("N3Vault"), "1") {
        permit2SignatureTransfer = permit2_;
    }

    function deposit(Permit2Transfer calldata permit2Transfer, bytes32 escrowId) external {
        _deposit(permit2Transfer, msg.sender, escrowId);
    }

    function depositFrom(
        Permit2Transfer calldata permit2Transfer,
        address from,
        bytes32 escrowId
    ) external {
        _deposit(permit2Transfer, from, escrowId);
    }

    function withdraw(bytes32 escrowId, TokenAmount[] calldata tokenAmount) external {
        Escrow storage escrow = escrowStatus[escrowId];

        if (escrow.locked == true) revert EscrowIsLocked();

        for (uint256 i; i < tokenAmount.length; ++i) {
            userEscrowBalance[msg.sender][tokenAmount[i].token][escrowId] -= tokenAmount[i].amount;
            escrowBalance[tokenAmount[i].token][escrowId] -= tokenAmount[i].amount;

            ERC20(tokenAmount[i].token).safeTransfer(msg.sender, tokenAmount[i].amount);

            // emit Withdraw(msg.sender, tokenAmount[i].token, escrowId, tokenAmount[i].amount);
        }
    }

    function balanceOfOnEscrow(
        address user,
        address token,
        bytes32 escrowId
    ) external view returns (uint256) {
        return userEscrowBalance[user][token][escrowId];
    }

    function activateEscrow(
        EscrowPermit calldata escrowPermit,
        uint256 requiredTokenBalance,
        bytes32 escrowId,
        bytes calldata escrowSignature
    ) external {
        if (block.timestamp > escrowPermit.deadline) revert SignatureExpired(escrowPermit.deadline);
        if (escrowPermit.locker != msg.sender) revert InvalidLocker();

        _useUnorderedNonce(escrowPermit.signer, escrowPermit.nonce);

        escrowSignature.verify(_hashTypedData(escrowPermit.hash()), escrowPermit.signer);

        // this needs to be updated to multiple token balances can be checked
        for (uint i; i < escrowPermit.tokens.length; ++i) {
            if (
                userEscrowBalance[escrowPermit.signer][escrowPermit.tokens[i]][escrowId] <
                requiredTokenBalance
            ) {
                revert InsufficientEscrowBalance();
            }
        }

        escrowStatus[escrowId] = Escrow(true, escrowPermit.locker);
    }

    function _deposit(
        Permit2Transfer calldata permit2Transfer,
        address from,
        bytes32 escrowId
    ) internal {
        permit2SignatureTransfer.permitTransferFrom(
            permit2Transfer.permit,
            permit2Transfer.transferDetails,
            from,
            permit2Transfer.signature
        );

        for (uint256 i; i < permit2Transfer.transferDetails.length; ++i) {
            if (permit2Transfer.transferDetails[i].to != address(this)) {
                continue;
            }

            escrowBalance[permit2Transfer.permit.permitted[i].token][escrowId] += permit2Transfer
                .transferDetails[i]
                .requestedAmount;

            userEscrowBalance[from][permit2Transfer.permit.permitted[i].token][
                escrowId
            ] += permit2Transfer.transferDetails[i].requestedAmount;

            // emit Deposit(from, permit2Transfer.transferDetails[i].token, escrowId, permit2Transfer.transferDetails[i].amount);
        }
    }
}
