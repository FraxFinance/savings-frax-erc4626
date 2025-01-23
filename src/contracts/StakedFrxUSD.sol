// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.21;

// ====================================================================
// |     ______                   _______                             |
// |    / _____________ __  __   / ____(_____  ____ _____  ________   |
// |   / /_  / ___/ __ `| |/_/  / /_  / / __ \/ __ `/ __ \/ ___/ _ \  |
// |  / __/ / /  / /_/ _>  <   / __/ / / / / / /_/ / / / / /__/  __/  |
// | /_/   /_/   \__,_/_/|_|  /_/   /_/_/ /_/\__,_/_/ /_/\___/\___/   |
// |                                                                  |
// ====================================================================
// =========================== StakedFrxUSD ===========================
// ====================================================================
// Frax Finance: https://github.com/FraxFinance

import { Timelock2Step } from "frax-std/access-control/v2/Timelock2Step.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeCastLib } from "solmate/utils/SafeCastLib.sol";
import { LinearRewardsErc4626, ERC20 } from "./LinearRewardsErc4626.sol";

/// @title Staked frxUSD
/// @notice A ERC4626 Vault implementation with linear rewards, rewards can be capped
contract StakedFrxUSD is LinearRewardsErc4626, Timelock2Step {
    using SafeCastLib for *;

    /// @notice The maximum amount of rewards that can be distributed per second per 1e18 asset
    uint256 public maxDistributionPerSecondPerAsset;

    uint256 private initializeStage = 2;

    /// @param _underlying The erc20 asset deposited
    /// @param _name The name of the vault
    /// @param _symbol The symbol of the vault
    /// @param _rewardsCycleLength The length of the rewards cycle in seconds
    /// @param _maxDistributionPerSecondPerAsset The maximum amount of rewards that can be distributed per second per 1e18 asset
    /// @param _timelockAddress The address of the timelock/owner contract
    constructor(
        IERC20 _underlying,
        string memory _name,
        string memory _symbol,
        uint32 _rewardsCycleLength,
        uint256 _maxDistributionPerSecondPerAsset,
        address _timelockAddress
    )
        LinearRewardsErc4626(ERC20(address(_underlying)), _name, _symbol, _rewardsCycleLength)
        Timelock2Step(_timelockAddress)
    {
        maxDistributionPerSecondPerAsset = _maxDistributionPerSecondPerAsset;
    }

    /// @notice The ```SetMaxDistributionPerSecondPerAsset``` event is emitted when the maxDistributionPerSecondPerAsset is set
    /// @param oldMax The old maxDistributionPerSecondPerAsset value
    /// @param newMax The new maxDistributionPerSecondPerAsset value
    event SetMaxDistributionPerSecondPerAsset(uint256 oldMax, uint256 newMax);

    error AlreadyInitialized();

    function initialize(
        string memory _name,
        string memory _symbol,
        uint256 _maxDistributionPerSecondPerAsset,
        address _timelockAddress
    ) external {
        if (initializeStage != 0) revert AlreadyInitialized();
        initializeStage++;
        name = _name;
        symbol = _symbol;
        maxDistributionPerSecondPerAsset = _maxDistributionPerSecondPerAsset;
        timelockAddress = _timelockAddress;

        // initialize rewardsCycleEnd value
        // NOTE: normally distribution of rewards should be done prior to _syncRewards but in this case we know there are no users or rewards yet.
        _syncRewards();

        // initialize lastRewardsDistribution value
        _distributeRewards();
    }

    /// @notice The ```initializeRewardsCycleData``` function initializes the rewards cycle data
    /// @dev This function can only be called once
    /// @param _pricePerShare The price per share
    /// @param _maxDistributionPerSecondPerAsset The maximum amount of rewards that can be distributed per second per 1e18 asset
    /// @param _cycleEnd The end of the rewards cycle
    /// @param _lastSync The last sync time
    /// @param _rewardCycleAmount The reward cycle amount
    function initializeRewardsCycleData(
        uint256 _pricePerShare,
        uint256 _maxDistributionPerSecondPerAsset,
        uint40 _cycleEnd,
        uint40 _lastSync,
        uint216 _rewardCycleAmount
    ) external {
        if (initializeStage != 1) revert AlreadyInitialized();
        initializeStage++;
        storedTotalAssets = (_pricePerShare * totalSupply) / PRECISION;
        maxDistributionPerSecondPerAsset = _maxDistributionPerSecondPerAsset;
        rewardsCycleData.cycleEnd = _cycleEnd;
        rewardsCycleData.lastSync = _lastSync;
        rewardsCycleData.rewardCycleAmount = _rewardCycleAmount;
    }

    /// @notice The ```setMaxDistributionPerSecondPerAsset``` function sets the maxDistributionPerSecondPerAsset
    /// @dev This function can only be called by the timelock, caps the value to type(uint64).max
    /// @param _maxDistributionPerSecondPerAsset The maximum amount of rewards that can be distributed per second per 1e18 asset
    function setMaxDistributionPerSecondPerAsset(uint256 _maxDistributionPerSecondPerAsset) external {
        _requireSenderIsTimelock();
        syncRewardsAndDistribution();

        // NOTE: prevents bricking the contract via overflow
        if (_maxDistributionPerSecondPerAsset > type(uint64).max) {
            _maxDistributionPerSecondPerAsset = type(uint64).max;
        }

        emit SetMaxDistributionPerSecondPerAsset({
            oldMax: maxDistributionPerSecondPerAsset,
            newMax: _maxDistributionPerSecondPerAsset
        });

        maxDistributionPerSecondPerAsset = _maxDistributionPerSecondPerAsset;
    }

    /// @notice The ```calculateRewardsToDistribute``` function calculates the amount of rewards to distribute based on the rewards cycle data and the time passed
    /// @param _rewardsCycleData The rewards cycle data
    /// @param _deltaTime The time passed since the last rewards distribution
    /// @return _rewardToDistribute The amount of rewards to distribute
    function calculateRewardsToDistribute(
        RewardsCycleData memory _rewardsCycleData,
        uint256 _deltaTime
    ) public view override returns (uint256 _rewardToDistribute) {
        _rewardToDistribute = super.calculateRewardsToDistribute({
            _rewardsCycleData: _rewardsCycleData,
            _deltaTime: _deltaTime
        });

        // Cap rewards
        uint256 _maxDistribution = (maxDistributionPerSecondPerAsset * _deltaTime * storedTotalAssets) / PRECISION;
        if (_rewardToDistribute > _maxDistribution) {
            _rewardToDistribute = _maxDistribution;
        }
    }
}
