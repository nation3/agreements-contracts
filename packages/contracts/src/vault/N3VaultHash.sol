// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import { IN3Vault } from "./IN3Vault.sol";

library N3VaultHash {
    bytes32 public constant ESCROW_PERMIT_TYPEHASH =
        keccak256(
            "EscrowPermit(bytes32 escrowId,address[] tokens,address locker,uint256 nonce,uint256 deadline)"
        );

    function hash(IN3Vault.EscrowPermit calldata escrowPermit) internal pure returns (bytes32) {
        uint256 numPermitted = escrowPermit.tokens.length;
        bytes32[] memory tokenHashes = new bytes32[](numPermitted);

        for (uint256 i = 0; i < numPermitted; ++i) {
            tokenHashes[i] = keccak256(abi.encode(escrowPermit.tokens[i]));
        }

        return
            keccak256(
                abi.encode(
                    ESCROW_PERMIT_TYPEHASH,
                    escrowPermit.escrowId,
                    keccak256(abi.encodePacked(tokenHashes)),
                    escrowPermit.locker,
                    escrowPermit.signer,
                    escrowPermit.nonce,
                    escrowPermit.deadline
                )
            );
    }
}
