// SPDX-License-Identifier: ISC
pragma solidity ^0.8.20;

import { BaseScript } from "frax-std/BaseScript.sol";
import { console } from "frax-std/FraxTest.sol";
import { FrxUSD } from "../contracts/FrxUSD.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { StorageSlot } from "@openzeppelin/contracts/utils/StorageSlot.sol";

import "../Constants.sol" as Constants;

function deployFrxUSD() returns (FrxUSD _frxUSD) {
    _frxUSD = new FrxUSD({ _ownerAddress: Constants.Mainnet.FRAX_ERC20_OWNER, _name: "Frax USD", _symbol: "frxUSD" });

    // Used for verification
    console.log("Constructor Arguments abi encoded: ");
    console.logBytes(abi.encode(Constants.Mainnet.FRAX_ERC20_OWNER, "Frax USD", "frxUSD"));
}

// NOTE: This contract deployed specifically to prevent known inflations attacks on share price in ERC4626
// And to set the initial rewards cycle data and price per share the same as the sFRAX contract
contract DeployProxyAndFrxUSD {
    function deployProxyAndFrxUSD() external returns (address _frxUSDAddress) {
        FrxUSD _frxUSDImplementation = deployFrxUSD();
        TransparentUpgradeableProxy _frxUSDUpgradeableProxy = new TransparentUpgradeableProxy(
            address(_frxUSDImplementation),
            Constants.Mainnet.FRAX_ERC20_OWNER,
            ""
        );
        _frxUSDAddress = address(_frxUSDUpgradeableProxy);
        FrxUSD(_frxUSDAddress).initialize(
            Constants.Mainnet.FRAX_ERC20_OWNER,
            _frxUSDImplementation.name(),
            _frxUSDImplementation.symbol()
        );
        console.log("Deployed FrxUSD at address: ", _frxUSDAddress);
    }
}

// This is a free function that can be imported and used in tests or other scripts
function deployDeployProxyAndFrxUSD() returns (address _frxUSDAddress) {
    DeployProxyAndFrxUSD _bundle = new DeployProxyAndFrxUSD();
    _frxUSDAddress = _bundle.deployProxyAndFrxUSD();
    console.log("Deployed frxUSD at address: ", _frxUSDAddress);
}

// Deploys frxUSD contract behind a proxy
contract DeployFrxUSD is BaseScript {
    function run() public broadcaster {
        address _address = deployDeployProxyAndFrxUSD();
    }
}
