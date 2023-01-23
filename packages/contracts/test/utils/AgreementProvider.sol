// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import { Vm, Test } from "forge-std/Test.sol";
import { Merkle } from "murky/Merkle.sol";
import { TestConstants } from "test/utils/Constants.sol";

import { AgreementParams, PositionParams } from "src/interfaces/AgreementTypes.sol";

contract CriteriaProvider is Test, TestConstants {
    Merkle merkle = new Merkle();

    uint256 criteria;
    mapping(address => bytes32[]) proofs;

    function setCriteria(PositionParams[] memory positions) public {
        bytes32[] memory leafs = new bytes32[](positions.length);

        for (uint256 i = 0; i < positions.length; i++) {
            leafs[i] = keccak256(
                abi.encode(positions[i].party, positions[i].balance)
            );
        }

        for (uint256 i = 0; i < positions.length; i++) {
            proofs[positions[i].party] = merkle.getProof(leafs, i);
        }

        bytes32 root = merkle.getRoot(leafs);
        criteria = uint256(root);
    }

    function setDefaultCriteria() public {
        PositionParams[] memory defaultPositions = new PositionParams[](2);
        defaultPositions[0] = PositionParams(bob, bobStake);
        defaultPositions[1] = PositionParams(alice, aliceStake);

        setCriteria(defaultPositions);
    }
}

contract AgreementProvider is Test {

    function getAgreementParams(address token, uint256 criteria) public pure returns (AgreementParams memory params) {
        params.termsHash = keccak256("Terms & Conditions");
        params.criteria = criteria;
        params.metadataURI = "ipfs://sha256";
        params.token = token;
    }
}
