// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import { IArbitrable } from "src/arbitrator/IArbitrable.sol";
import { IArbitrator } from "src/arbitrator/IArbitrator.sol";

contract MockArbitrable is IArbitrable {
    mapping(bytes32 => uint8) public disputeStatus;
    uint256 internal idCounter;
    address public arbitrator;
    uint256 public arbitrationFee;

    function setUp(address arbitrator_) public {
        arbitrator = arbitrator_;
    }

    function createDispute() public returns (bytes32) {
        bytes32 id = keccak256(abi.encode(idCounter));
        disputeStatus[id] = 1;
        idCounter += 1;
        return id;
    }

    function settle(bytes32 id, bytes calldata settlement) public {
        if (msg.sender != arbitrator) revert NotArbitrator();
        // TODO: Update this
        if (settlement.length <= 0) revert IArbitrator.SettlementPositionsMustMatch();
        disputeStatus[id] = 2;
    }

    function canAppeal(bytes32 id, address user) public view returns (bool) {
        return true;
    }
}
