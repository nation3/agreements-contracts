// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import { Vm, Test } from "forge-std/Test.sol";

contract TestConstants is Test {
    address bob = vm.addr(0xB0B);
    address alice = vm.addr(0xA11CE);
    address cafe = vm.addr(0xCAFE);
    address food = vm.addr(0xF00D);
    address beef = vm.addr(0xBEEF);
    address face = vm.addr(0xFACE);
    address dead = vm.addr(0xDEAD);
    address bed = vm.addr(0xBED);
    address fade = vm.addr(0xFADE);
    address cab = vm.addr(0xCAB);

    uint256 bobStake = 2 * 1e18;
    uint256 aliceStake = 1 * 1e18;

    // add more stakes
}
