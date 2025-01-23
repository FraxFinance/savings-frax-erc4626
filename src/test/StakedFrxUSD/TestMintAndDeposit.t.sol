// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "./BaseTestStakedFrxUSD.sol";
import { StakedFrxUSDFunctions } from "./TestSetMaxDistributionPerSecondPerAsset.t.sol";

abstract contract mintDepositFunctions is BaseTestStakedFrxUSD {
    function _stakedFrxUSD_mint(uint256 _amount, address _recipient) internal {
        hoax(_recipient);
        stakedFrxUSD.mint(_amount, _recipient);
    }

    function _stakedFrxUSD_deposit(uint256 _amount, address _recipient) internal {
        hoax(_recipient);
        stakedFrxUSD.deposit(_amount, _recipient);
    }
}

contract TestMintAndDepositSfrxUSD is BaseTestStakedFrxUSD, StakedFrxUSDFunctions, mintDepositFunctions {
    /// FEATURE: mint and deposit

    using StakedFrxUSDStructHelper for *;

    address bob;
    address alice;
    address donald;

    address joe;

    function setUp() public {
        /// BACKGROUND: deploy the StakedFrxUSD contract
        /// BACKGROUND: 10% APY cap
        /// BACKGROUND: frax as the underlying asset
        /// BACKGROUND: TIMELOCK_ADDRESS set as the timelock address
        defaultSetup();

        bob = labelAndDeal(address(1234), "bob");
        mintFraxTo(bob, 5000 ether);
        hoax(bob);
        fraxErc20.approve(stakedFrxUSDAddress, type(uint256).max);

        alice = labelAndDeal(address(2345), "alice");
        mintFraxTo(alice, 5000 ether);
        hoax(alice);
        fraxErc20.approve(stakedFrxUSDAddress, type(uint256).max);

        donald = labelAndDeal(address(3456), "donald");
        mintFraxTo(donald, 5000 ether);
        hoax(donald);
        fraxErc20.approve(stakedFrxUSDAddress, type(uint256).max);

        joe = labelAndDeal(address(4567), "joe");
        mintFraxTo(joe, 5000 ether);
        hoax(joe);
        fraxErc20.approve(stakedFrxUSDAddress, type(uint256).max);
    }

    function test_CanDepositNoRewards() public {
        /// SCENARIO: No rewards distribution, A user deposits 1000 FRAX and should have 50% of the shares

        //==============================================================================
        // Act
        //==============================================================================

        StakedFrxUSDStorageSnapshot memory _initial_stakedFrxUSDStorageSnapshot = stakedFrxUSDStorageSnapshot(
            stakedFrxUSD
        );

        /// WHEN: bob deposits 1000 FRAX
        _stakedFrxUSD_deposit(1000 ether, bob);

        DeltaStakedFrxUSDStorageSnapshot memory _delta_stakedFrxUSDStorageSnapshot = deltaStakedFrxUSDStorageSnapshot(
            _initial_stakedFrxUSDStorageSnapshot
        );

        //==============================================================================
        // Assert
        //==============================================================================

        /// THEN: The user should have 1000 shares
        uint256 bobShares = (1000e18 * 1e18) / stakedFrxUSD.pricePerShare();
        assertEq(stakedFrxUSD.balanceOf(bob), bobShares, "THEN: The user should have 1000 FRAX worth of shares");

        /// THEN: The totalSupply should have increased by specific number of shares
        assertEq(
            _delta_stakedFrxUSDStorageSnapshot.delta.totalSupply,
            bobShares,
            "THEN: The totalSupply should have increased by specific number of  shares"
        );

        /// THEN: The storedTotalAssets should have increased by 1000 FRAX
        assertEq(
            _delta_stakedFrxUSDStorageSnapshot.delta.storedTotalAssets,
            1000 ether,
            "THEN: The storedTotalAssets should have increased by specific number of  FRAX"
        );
    }

    function test_CanDepositAndMintWithRewardsCappedRewards() public {
        /// SCENARIO: A user deposits 1000 FRAX and should have 50% of the shares, 600 FRAX is distributed as rewards, uncapped

        //==============================================================================
        // Arrange
        //==============================================================================

        StakedFrxUSDStorageSnapshot memory _initial_stakedFrxUSDSnapshot = stakedFrxUSDStorageSnapshot(stakedFrxUSD);

        /// GIVEN: maxDistributionPerSecondPerAsset is at 3_033_347_948 per second per 1e18 asset (roughly 10% APY)
        uint256 _maxDistributionPerSecondPerAsset = 3_033_347_948;
        _stakedFrxUSD_setMaxDistributionPerSecondPerAsset(_maxDistributionPerSecondPerAsset);

        /// GIVEN: timestamp is 400_000 seconds away from the end of the cycle
        uint256 _syncDuration = 400_000;
        mineBlocksToTimestamp(stakedFrxUSD.__rewardsCycleData().cycleEnd + rewardsCycleLength - _syncDuration);

        /// GIVEN: 600 FRAX is transferred as rewards
        uint256 _rewards = 600 ether;
        mintFraxTo(stakedFrxUSDAddress, _rewards);

        /// GIVEN: syncAndDistributeRewards is called
        stakedFrxUSD.syncRewardsAndDistribution();

        /// GIVEN: We wait 100_000 seconds
        uint256 _timeSinceLastRewardsDistribution = 100_000;
        mineBlocksBySecond(_timeSinceLastRewardsDistribution);

        //==============================================================================
        // Act
        //==============================================================================

        DeltaStakedFrxUSDStorageSnapshot
            memory _second_deltaStakedFrxUSDStorageSnapshot = deltaStakedFrxUSDStorageSnapshot(
                _initial_stakedFrxUSDSnapshot
            );

        uint256 _pricePerShare = stakedFrxUSD.pricePerShare();

        /// WHEN: A user deposits 1000 FRAX
        _stakedFrxUSD_deposit(1000 ether, bob);

        DeltaStakedFrxUSDStorageSnapshot
            memory _third_deltaStakedFrxUSDStorageSnapshot = deltaStakedFrxUSDStorageSnapshot(
                _second_deltaStakedFrxUSDStorageSnapshot.end
            );

        //==============================================================================
        // Assert
        //==============================================================================
        uint256 _expectedRewards = (_second_deltaStakedFrxUSDStorageSnapshot.end.storedTotalAssets *
            _maxDistributionPerSecondPerAsset *
            _timeSinceLastRewardsDistribution) / 1e18;
        /// THEN: the storedTotalAssets should have increased the rewards and 1000 frax for the deposit
        assertEq(
            _third_deltaStakedFrxUSDStorageSnapshot.delta.storedTotalAssets,
            1000 ether + _expectedRewards,
            "storedTotalAssets should have increased by _expectedFrax for the rewards and 1000 frax for the deposit"
        );

        // _expected = newAssets* pricePerShare
        uint256 _expectedShares = (1000e18 * 1e18) / _pricePerShare;
        /// THEN: The user should have 1000e18 * 1000e18 / 1150e18 shares
        assertApproxEqAbs(
            stakedFrxUSD.balanceOf(bob),
            _expectedShares,
            1000,
            "THEN: The user should have the correct amount of shares"
        );

        /// THEN: The totalSupply should have increased by _expectedShares
        assertApproxEqAbs(
            _third_deltaStakedFrxUSDStorageSnapshot.delta.totalSupply,
            _expectedShares,
            1000,
            " THEN: The totalSupply should have increased by _expectedShares"
        );
    }

    function test_CanMintWithRewardsCappedRewards() public {
        /// SCENARIO: A user deposits 1000 FRAX and should have 50% of the shares, 600 FRAX is distributed as rewards, uncapped

        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: maxDistributionPerSecondPerAsset is at 3_033_347_948 per second per 1e18 asset (roughly 10% APY)
        uint256 _maxDistributionPerSecondPerAsset = 3_033_347_948;
        _stakedFrxUSD_setMaxDistributionPerSecondPerAsset(_maxDistributionPerSecondPerAsset);

        /// GIVEN: timestamp is 400_000 seconds away from the end of the cycle
        uint256 _syncDuration = 400_000;
        mineBlocksToTimestamp(stakedFrxUSD.__rewardsCycleData().cycleEnd + rewardsCycleLength - _syncDuration);

        /// GIVEN: 600 FRAX is transferred as rewards
        uint256 _rewards = 600 ether;
        mintFraxTo(stakedFrxUSDAddress, _rewards);

        /// GIVEN: syncAndDistributeRewards is called
        stakedFrxUSD.syncRewardsAndDistribution();

        /// GIVEN: We wait 100_000 seconds
        uint256 _timeSinceLastRewardsDistribution = 100_000;
        mineBlocksBySecond(_timeSinceLastRewardsDistribution);

        //==============================================================================
        // Act
        //==============================================================================

        StakedFrxUSDStorageSnapshot memory _initial_stakedFrxUSDSnapshot = stakedFrxUSDStorageSnapshot(stakedFrxUSD);

        /// WHEN: A user mints 1000 FRAX
        uint256 _pricePerShare = stakedFrxUSD.pricePerShare();
        _stakedFrxUSD_mint(1000 ether, bob);

        DeltaStakedFrxUSDStorageSnapshot
            memory _fourth_deltaStakedFrxUSDStorageSnapshot = deltaStakedFrxUSDStorageSnapshot(
                _initial_stakedFrxUSDSnapshot
            );

        //==============================================================================
        // Assert
        //==============================================================================
        uint256 _expectedRewards = (_initial_stakedFrxUSDSnapshot.storedTotalAssets *
            _maxDistributionPerSecondPerAsset *
            _timeSinceLastRewardsDistribution) / 1e18;
        uint256 _expectedAmountTransferred = (1000 ether * _pricePerShare) / 1e18;

        /// THEN: the storedTotalAssets should have increased by specific amount
        assertApproxEqAbs(
            _fourth_deltaStakedFrxUSDStorageSnapshot.delta.storedTotalAssets,
            _expectedAmountTransferred + _expectedRewards,
            1000,
            "storedTotalAssets should have increased by _expectedRewards frax for the rewards and _expectedAmountTransferred frax for the mint"
        );

        /// THEN: the user should have 1000 shares
        assertEq(stakedFrxUSD.balanceOf(bob), 1000 ether, "THEN: the user should have 1000 shares");

        /// THEN: The totalSupply should have increased by 1000
        assertEq(
            _fourth_deltaStakedFrxUSDStorageSnapshot.delta.totalSupply,
            1000 ether,
            " THEN: The totalSupply should have increased by 1000"
        );
    }

    function test_CanMintWithRewardsNoCap() public {
        /// SCENARIO: A user deposits 1000 FRAX and should have 50% of the shares, 600 FRAX is distributed as rewards, uncapped

        //==============================================================================
        // Arrange
        //==============================================================================

        uint256 _maxDistributionPerSecondPerAsset = type(uint256).max;
        uint256 _syncDuration = 400_000;
        uint256 _timeSinceLastRewardsDistribution = 100_000;
        uint256 _rewards = 600 ether;

        StakedFrxUSDStorageSnapshot memory _initial_stakedFrxUSDSnapshot = stakedFrxUSDStorageSnapshot(stakedFrxUSD);

        /// GIVEN: maxDistributionPerSecondPerAsset is uncapped
        _stakedFrxUSD_setMaxDistributionPerSecondPerAsset(_maxDistributionPerSecondPerAsset);

        /// GIVEN: timestamp is 400_000 seconds away from the end of the cycle
        mineBlocksToTimestamp(stakedFrxUSD.__rewardsCycleData().cycleEnd + rewardsCycleLength - _syncDuration);

        /// GIVEN: 600 FRAX is transferred as rewards
        mintFraxTo(stakedFrxUSDAddress, _rewards);

        /// GIVEN: syncAndDistributeRewards is called
        stakedFrxUSD.syncRewardsAndDistribution();

        /// GIVEN: We wait 100_000 seconds
        mineBlocksBySecond(_timeSinceLastRewardsDistribution);

        //==============================================================================
        // Act
        //==============================================================================

        DeltaStakedFrxUSDStorageSnapshot
            memory _second_deltaStakedFrxUSDStorageSnapshot = deltaStakedFrxUSDStorageSnapshot(
                _initial_stakedFrxUSDSnapshot
            );

        uint256 _pricePerShare = stakedFrxUSD.pricePerShare();

        /// WHEN: A user mints 1000 FRAX
        _stakedFrxUSD_mint(1000 ether, bob);

        DeltaStakedFrxUSDStorageSnapshot
            memory _third_deltaSavingsFraxStorageSnapshot = deltaStakedFrxUSDStorageSnapshot(
                _second_deltaStakedFrxUSDStorageSnapshot.end
            );

        //==============================================================================
        // Assert
        //==============================================================================

        uint256 _expectedRewards = (_second_deltaStakedFrxUSDStorageSnapshot.end.rewardsCycleData.rewardCycleAmount *
            _timeSinceLastRewardsDistribution) / 400_000;
        uint256 _storedTotalAssetsDelta = (1000e18 * _pricePerShare) / 1e18 + _expectedRewards;

        /// THEN: the storedTotalAssets should have increased by the mint and rewards
        assertApproxEqAbs(
            _third_deltaSavingsFraxStorageSnapshot.delta.storedTotalAssets,
            _storedTotalAssetsDelta,
            1000,
            "storedTotalAssets should have increased by the mint and rewards"
        );

        /// THEN: the user should have 1000 shares
        assertEq(stakedFrxUSD.balanceOf(bob), 1000 ether, "THEN: the user should have 1000 shares");
    }

    function test_CanDepositWithRewardsCap() public {
        /// SCENARIO: A user deposits 1000 FRAX and should have 50% of the shares, 600 FRAX is distributed as rewards, uncapped

        //==============================================================================
        // Arrange
        //==============================================================================

        uint256 _maxDistributionPerSecondPerAsset = type(uint256).max;
        uint256 _syncDuration = 400_000;
        uint256 _timeSinceLastRewardsDistribution = 100_000;
        uint256 _rewards = 600 ether;

        /// GIVEN: maxDistributionPerSecondPerAsset is uncapped
        _stakedFrxUSD_setMaxDistributionPerSecondPerAsset(_maxDistributionPerSecondPerAsset);

        /// GIVEN: timestamp is 400_000 seconds away from the end of the cycle
        mineBlocksToTimestamp(stakedFrxUSD.__rewardsCycleData().cycleEnd + rewardsCycleLength - _syncDuration);

        /// GIVEN: 600 FRAX is transferred as rewards
        mintFraxTo(stakedFrxUSDAddress, _rewards);

        /// GIVEN: syncAndDistributeRewards is called
        stakedFrxUSD.syncRewardsAndDistribution();

        StakedFrxUSDStorageSnapshot memory _initial_stakedFrxUSDSnapshot = stakedFrxUSDStorageSnapshot(stakedFrxUSD);

        /// GIVEN: We wait 100_000 seconds
        mineBlocksBySecond(_timeSinceLastRewardsDistribution);
        //==============================================================================
        // Deposit Test
        //==============================================================================

        /// WHEN: A user deposits 1000 FRAX
        uint256 _pricePerShare = stakedFrxUSD.pricePerShare();
        _stakedFrxUSD_deposit(1000 ether, bob);

        DeltaStakedFrxUSDStorageSnapshot
            memory _second_deltaStakedFrxUSDStorageSnapshot = deltaStakedFrxUSDStorageSnapshot(
                _initial_stakedFrxUSDSnapshot
            );

        //==============================================================================
        // Assert
        //==============================================================================

        /// THEN: the storedTotalAssets should have increased by the deposit and the rewards
        uint256 _expectedRewards = (_initial_stakedFrxUSDSnapshot.rewardsCycleData.rewardCycleAmount *
            _timeSinceLastRewardsDistribution) / 400_000;
        uint256 _storedTotalAssetsDelta = 1000 ether + _expectedRewards;
        assertEq(
            _second_deltaStakedFrxUSDStorageSnapshot.delta.storedTotalAssets,
            _storedTotalAssetsDelta,
            "storedTotalAssets should have increased by deposit and the rewards"
        );

        // _expected = newAssets / sharePrice, sharePrice = assets / shares
        uint256 _expectedShares = (1000e18 * 1e18) / _pricePerShare;
        /// THEN: The user should have 1000 worth of shares
        assertApproxEqAbs(
            stakedFrxUSD.balanceOf(bob),
            _expectedShares,
            1000,
            "THEN: The user should have 1000 worth of shares"
        );

        /// THEN: The totalSupply should have increased by 1000
        assertApproxEqAbs(
            _second_deltaStakedFrxUSDStorageSnapshot.delta.totalSupply,
            _expectedShares,
            1000,
            " THEN: The totalSupply should have increased by 1000"
        );
    }
}
