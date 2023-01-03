// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import { Vm, Test } from "forge-std/Test.sol";

contract TestConstants is Test {

    address arbitrator = address(0xB055);
    address bob = vm.addr(0xB0B);
    address alice = vm.addr(0xA11CE);

    uint256 bobStake = 2 * 1e18;
    uint256 aliceStake = 1 * 1e18;
}
