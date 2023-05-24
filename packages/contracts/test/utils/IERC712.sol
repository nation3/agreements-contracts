// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

// Permit2's ISignatureTransfer interface does not contain a function for accessing DOMAIN_SEPARATOR
// Ref: https://github.com/Uniswap/permit2/issues/193
interface IEIP712 {
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}
