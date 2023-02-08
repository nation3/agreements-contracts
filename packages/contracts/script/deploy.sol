// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import { Script, console } from "forge-std/Script.sol";

import { MockERC20, ERC20 } from "solmate/src/test/utils/mocks/MockERC20.sol";
import { Permit2 } from "permit2/src/Permit2.sol";

import { DeploymentUtils } from "script/DeploymentUtils.sol";

import { DepositConfig } from "src/utils/interfaces/Deposits.sol";
import { Arbitrator } from "src/Arbitrator.sol";
import { CollateralAgreementFramework } from "src/frameworks/CollateralAgreement.sol";

contract DeployStack is Script, DeploymentUtils {
    /// Environment variables
    address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    bytes32 constant SALT = bytes32(uint256(0x314));

    address ARBITRATOR;
    address ARBITRATION_TOKEN;
    uint256 DISPUTE_COST = 0;
    uint256 APPEAL_COST = 0;
    uint256 RESOLUTION_LOCK_PERIOD = 4 hours + 20 minutes;

    function setUpArbitrator() internal {
        if (ARBITRATOR == address(0)) {
            address arbitrationToken = registeredContractsAddress["ArbitrationToken"];

            Arbitrator arbitrator = new Arbitrator{ salt: SALT }(Permit2(PERMIT2), tx.origin);
            arbitrator.setUp(
                RESOLUTION_LOCK_PERIOD,
                true,
                DepositConfig(arbitrationToken, APPEAL_COST, tx.origin)
            );

            registerContract("Arbitrator", address(arbitrator));
        } else {
            registerContract("Arbitrator", ARBITRATOR);
        }
    }

    function setUpFramework() internal {
        address arbitrationToken = registeredContractsAddress["ArbitrationToken"];
        address arbitrator = registeredContractsAddress["Arbitrator"];

        CollateralAgreementFramework framework = new CollateralAgreementFramework{ salt: SALT }(
            Permit2(PERMIT2),
            tx.origin
        );
        framework.setUp(arbitrator, DepositConfig(arbitrationToken, DISPUTE_COST, tx.origin));

        registerContract("CollateralAgreementFramework", address(framework));
    }

    function loadEnvVars() internal {
        ARBITRATOR = loadEnvAddress(ARBITRATOR, "ARBITRATOR");
        ARBITRATION_TOKEN = loadEnvAddress(ARBITRATION_TOKEN, "ARBITRATION_TOKEN");
        DISPUTE_COST = loadEnvUint(DISPUTE_COST, "DISPUTE_COST");
        APPEAL_COST = loadEnvUint(APPEAL_COST, "APPEAL_COST");
        RESOLUTION_LOCK_PERIOD = loadEnvUint(RESOLUTION_LOCK_PERIOD, "RESOLUTION_LOCK_PERIOD");
    }

    function storeDeploymentManifest() internal {
        string memory manifest = generateRegisteredContractsJson();

        mkdir(deploymentsPath(""));

        vm.writeFile(deploymentsPath("latest.json"), manifest);

        console.log("Stored deployment manifest at %s.", deploymentsPath("latest.json"));
    }

    function setupTokens() internal {
        address arbitrationToken;
        if (ARBITRATION_TOKEN == address(0)) {
            MockERC20 newToken = new MockERC20("Court Token", "CT", 18);
            newToken.mint(tx.origin, 314 * 1e18);
            arbitrationToken = address(newToken);
        } else {
            arbitrationToken = ARBITRATION_TOKEN;
        }

        registerContract("ArbitrationToken", arbitrationToken);
    }

    function setUpContracts() internal {
        setupTokens();
        setUpArbitrator();
        setUpFramework();
    }

    function run() public {
        loadEnvVars();

        vm.startBroadcast();

        setUpContracts();

        vm.stopBroadcast();

        logDeployments();

        storeDeploymentManifest();
    }
}
