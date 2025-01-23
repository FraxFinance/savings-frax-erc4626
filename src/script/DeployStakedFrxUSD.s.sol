// SPDX-License-Identifier: ISC
pragma solidity ^0.8.20;

import { BaseScript } from "frax-std/BaseScript.sol";
import { console } from "frax-std/FraxTest.sol";
import { StakedFrxUSD } from "../contracts/StakedFrxUSD.sol";
import { StakedFrax } from "../contracts/StakedFrax.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../Constants.sol" as Constants;

address constant SFRAX_ERC4626 = 0xA663B02CF0a4b149d2aD41910CB81e23e1c41c32;
address constant FRXUSD = 0xCAcd6fd266aF91b8AeD52aCCc382b4e165586E29;

function deployStakedFrxUSD() returns (StakedFrxUSD _stakedFrxUSD) {
    uint256 TEN_PERCENT = 3_022_266_030; // per second rate compounded week each block (1.10^(365 * 86400 / 12) - 1) / 12 * 1e18

    _stakedFrxUSD = new StakedFrxUSD({
        _underlying: IERC20(FRXUSD),
        _name: "Staked Frax USD",
        _symbol: "sfrxUSD",
        _rewardsCycleLength: 7 days,
        _maxDistributionPerSecondPerAsset: TEN_PERCENT,
        _timelockAddress: Constants.Mainnet.FRAX_ERC20_OWNER
    });

    // Used for verification
    console.log("Constructor Arguments abi encoded: ");
    console.logBytes(
        abi.encode(
            IERC20(FRXUSD),
            "Staked Frax USD",
            "sfrxUSD",
            7 days,
            TEN_PERCENT,
            Constants.Mainnet.FRAX_ERC20_OWNER
        )
    );
}

// NOTE: This contract deployed specifically to prevent known inflations attacks on share price in ERC4626
// And to set the initial rewards cycle data and price per share the same as the sFRAX contract
contract DeployAndDepositStakedFrxUSD {
    function deployStakedFrxUSDAndDeposit() external returns (address _stakedFrxUSDAddress) {
        StakedFrxUSD _stakedFrxUSDImplementation = deployStakedFrxUSD();
        TransparentUpgradeableProxy _stakedFrxUSDUpgradeableProxy = new TransparentUpgradeableProxy(
            address(_stakedFrxUSDImplementation),
            Constants.Mainnet.FRAX_ERC20_OWNER,
            ""
        );
        StakedFrxUSD _stakedFrxUSD = StakedFrxUSD(address(_stakedFrxUSDUpgradeableProxy));
        _stakedFrxUSD.initialize(
            _stakedFrxUSDImplementation.name(),
            _stakedFrxUSDImplementation.symbol(),
            _stakedFrxUSDImplementation.maxDistributionPerSecondPerAsset(),
            Constants.Mainnet.FRAX_ERC20_OWNER
        );
        _stakedFrxUSDAddress = address(_stakedFrxUSD);
        StakedFrax _stakedFrax = StakedFrax(SFRAX_ERC4626);
        _stakedFrax.syncRewardsAndDistribution();
        uint256 _pricePerShare = _stakedFrax.pricePerShare();
        uint256 _balance = IERC20(FRXUSD).balanceOf(address(this));
        IERC20(FRXUSD).approve(address(_stakedFrxUSD), 1000e18);
        _stakedFrxUSD.deposit(1000e18, Constants.Mainnet.FRAX_ERC20_OWNER);
        IERC20(FRXUSD).transfer(address(_stakedFrxUSD), _balance - 1000e18);
        (uint40 _cycleEnd, uint40 _lastSync, ) = _stakedFrax.rewardsCycleData();
        uint216 _rewardCycleAmount = uint216(
            ((_balance - (1000e18 * _pricePerShare) / 1e18) * (_cycleEnd - _lastSync)) / (_cycleEnd - block.timestamp)
        );
        _stakedFrxUSD.initializeRewardsCycleData(
            _pricePerShare,
            _stakedFrax.maxDistributionPerSecondPerAsset(),
            _cycleEnd,
            _lastSync,
            _rewardCycleAmount
        );
    }
}

// This is a free function that can be imported and used in tests or other scripts
function deployDeployAndDepositStakedFrxUSD() returns (address _stakedFrxUSDAddress) {
    DeployAndDepositStakedFrxUSD _bundle = new DeployAndDepositStakedFrxUSD();
    IERC20(FRXUSD).transfer(address(_bundle), 2000e18);
    _stakedFrxUSDAddress = _bundle.deployStakedFrxUSDAndDeposit();
    console.log("Deployed StakedFrxUSD at address: ", _stakedFrxUSDAddress);
}

// This script only deploys the DeployAndDepositStakedFrxUSD contract
// You then need to deposit enough frxUSD into the contract and call deployStakedFrxUSDAndDeposit() for sfrxUSD to be deployed.
// For the rates to be synced with sFRAX, there needs to be enough FRAX in sFRAX and enough frxUSD in sfrxUSD for them both to be at the capped rate.
// syncRewardsAndDistribution also needs to be called in sync after the new epoch for sFRAX and sfrxUSD to keep the same price.
contract DeployStakedFrxUSD is BaseScript {
    function run() public broadcaster {
        address _address = address(new DeployAndDepositStakedFrxUSD());
        console.log("Deployed DeployAndDepositStakedFrxUSD at address: ", _address);
    }
}
