// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import { Vm, Test } from "forge-std/Test.sol";
import { MockERC20 } from "solmate/src/test/utils/mocks/MockERC20.sol";
import { Permit2 } from "permit2/src/Permit2.sol";

contract TokenProvider is Test {
    Permit2 permit2;

    MockERC20 tokenA;
    MockERC20 tokenB;

    uint256 public constant MINT_AMOUNT_ERC20 = 42 * 1e18;

    function initializeERC20Tokens() public {
        permit2 = new Permit2();

        tokenA = new MockERC20("Test Token A", "TA", 18);
        tokenB = new MockERC20("Test Token B", "TB", 18);
    }

    function setERC20TestTokens(address to) public {
        tokenA.mint(to, MINT_AMOUNT_ERC20);
        tokenB.mint(to, MINT_AMOUNT_ERC20);
    }
    
    function setERC20TestTokenApprovals(Vm vm, address owner, address spender) public {
        vm.startPrank(owner);
        tokenA.approve(spender, type(uint256).max);
        tokenB.approve(spender, type(uint256).max);
        vm.stopPrank();
    }
}
