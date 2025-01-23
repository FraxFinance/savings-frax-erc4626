// SPDX-License-Identifier: ISC
pragma solidity ^0.8.20;

import { BaseScript } from "frax-std/BaseScript.sol";
import { console } from "frax-std/FraxTest.sol";
import { FrxUSDCustodianFactory } from "../contracts/FrxUSDCustodianFactory.sol";

import "../Constants.sol" as Constants;

address constant FRXUSD = 0xCAcd6fd266aF91b8AeD52aCCc382b4e165586E29;

// Deploys the FrxUSDCustodian contract behind a proxy
contract DeployFrxUSDCustodianFactory is BaseScript {
    function run() public broadcaster {
        FrxUSDCustodianFactory _factory = new FrxUSDCustodianFactory(Constants.Mainnet.FRAX_ERC20_OWNER, FRXUSD);
        console.log("FrxUSDCustodianFactory deployed at:", address(_factory));
    }
}
