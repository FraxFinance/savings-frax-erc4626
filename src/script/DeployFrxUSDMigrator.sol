// SPDX-License-Identifier: ISC
pragma solidity ^0.8.20;

import { BaseScript } from "frax-std/BaseScript.sol";
import { console } from "frax-std/FraxTest.sol";
import { FrxUSDMigrator } from "../contracts/FrxUSDMigrator.sol";
import "../Constants.sol" as Constants;

// Deploys the FrxUSDMigrator contract
contract DeployFrxUSDMigrator is BaseScript {
    function run() public broadcaster {
        FrxUSDMigrator _migrator = new FrxUSDMigrator();
        console.log("FrxUSDMigrator deployed at:", address(_migrator));
    }
}
