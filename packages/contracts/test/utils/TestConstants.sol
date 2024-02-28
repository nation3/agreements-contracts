// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import { Vm, Test } from "forge-std/Test.sol";

contract TestConstants is Test {
    uint256[] testSubjectKeys = [
        0xB0B,
        0xA11CE,
        0xCAFE,
        0xF00D,
        0xBEEF,
        0xFACE,
        0xDEAD,
        0xBED,
        0xFADE,
        0xCAB
    ];

    address[] testSubjects = [
        vm.addr(0xB0B),
        vm.addr(0xA11CE),
        vm.addr(0xCAFE),
        vm.addr(0xF00D),
        vm.addr(0xBEEF),
        vm.addr(0xFACE),
        vm.addr(0xDEAD),
        vm.addr(0xBED),
        vm.addr(0xFADE),
        vm.addr(0xCAB)
    ];
}
