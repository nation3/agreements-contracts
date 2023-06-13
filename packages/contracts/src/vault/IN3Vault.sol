// // SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import { ISignatureTransfer } from "permit2/src/interfaces/ISignatureTransfer.sol";

interface IN3Vault {
    error InsufficientEscrowBalance();
    error InvalidLocker();
    error EscrowIsLocked();

    struct TokenAmount {
        address token;
        uint256 amount;
    }

    struct Permit2Transfer {
        ISignatureTransfer.SignatureTransferDetails[] transferDetails;
        ISignatureTransfer.PermitBatchTransferFrom permit;
        bytes signature;
    }

    struct EscrowPermit {
        bytes32 escrowId;
        address[] tokens;
        address locker;
        address signer;
        uint256 nonce;
        uint256 deadline;
    }

    struct Escrow {
        bool locked;
        address locker;
    }
}
