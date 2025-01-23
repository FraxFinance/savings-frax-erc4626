// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "./BaseTestStakedFrxUSD.sol";

contract TestDistributeRewards is BaseTestStakedFrxUSD {
    /// FEATURE: rewards distribution

    using StakedFrxUSDStructHelper for *;
    using ArrayHelper for function()[];

    address bob;
    address alice;
    address donald;

    function setUp() public virtual {
        /// BACKGROUND: deploy the StakedFrxUSD contract
        /// BACKGROUND: 10% APY cap
        /// BACKGROUND: frax as the underlying asset
        /// BACKGROUND: TIMELOCK_ADDRESS set as the timelock address
        defaultSetup();

        bob = labelAndDeal(address(1234), "bob");
        mintFraxTo(bob, 1000 ether);
        hoax(bob);
        fraxErc20.approve(stakedFrxUSDAddress, type(uint256).max);

        alice = labelAndDeal(address(2345), "alice");
        mintFraxTo(alice, 1000 ether);
        hoax(alice);
        fraxErc20.approve(stakedFrxUSDAddress, type(uint256).max);

        donald = labelAndDeal(address(3456), "donald");
        mintFraxTo(donald, 1000 ether);
        hoax(donald);
        fraxErc20.approve(stakedFrxUSDAddress, type(uint256).max);
    }

    function test_DistributeRewardsWithInitialRewards() public {
        /// SCENARIO: syncRewardsAndDistribution() is called when there are no rewards

        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: move forward 1 day
        mineBlocksBySecond(1 days);

        //==============================================================================
        // Act
        //==============================================================================

        StakedFrxUSDStorageSnapshot memory _initial_stakedFrxUSDStorageSnapshot = stakedFrxUSDStorageSnapshot(
            stakedFrxUSD
        );

        /// WHEN: anyone calls syncRewardsAndDistribution()
        stakedFrxUSD.syncRewardsAndDistribution();

        DeltaStakedFrxUSDStorageSnapshot memory _delta_stakedFrxUSDStorageSnapshot = deltaStakedFrxUSDStorageSnapshot(
            _initial_stakedFrxUSDStorageSnapshot
        );

        //==============================================================================
        // Assert
        //==============================================================================

        /// THEN: lastDistributionTime should be current timestamp
        assertEq(
            _delta_stakedFrxUSDStorageSnapshot.end.lastRewardsDistribution,
            block.timestamp,
            "THEN: lastDistributionTime should be current timestamp"
        );

        /// THEN: lastDistributionTime should have changed by 1 day
        assertEq(
            _delta_stakedFrxUSDStorageSnapshot.delta.lastRewardsDistribution,
            1 days,
            "THEN: lastDistributionTime should have changed by 1 day"
        );

        /// THEN: totalSupply should not have changed
        assertEq(_delta_stakedFrxUSDStorageSnapshot.delta.totalSupply, 0, "THEN: totalSupply should not have changed");

        /// THEN: storedTotalAssets should be the capped rate
        uint256 calculatedDelta = (_initial_stakedFrxUSDStorageSnapshot.storedTotalAssets *
            _initial_stakedFrxUSDStorageSnapshot.maxDistributionPerSecondPerAsset *
            1 days) / 1e18;
        assertEq(
            _delta_stakedFrxUSDStorageSnapshot.delta.storedTotalAssets,
            calculatedDelta,
            "THEN: storedTotalAssets should be the capped rate"
        );
    }

    function test_distributeRewardsInTheSameBlock() public {
        /// SCENARIO: syncRewardsAndDistribution() is called twice in the same block

        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: current timestamp is equal to lastRewardsDistribution
        mineBlocksToTimestamp(stakedFrxUSD.lastRewardsDistribution());

        //==============================================================================
        // Act
        //==============================================================================

        StakedFrxUSDStorageSnapshot memory _initial_stakedFrxUSDStorageSnapshot = stakedFrxUSDStorageSnapshot(
            stakedFrxUSD
        );

        /// WHEN: anyone calls syncRewardsAndDistribution()
        stakedFrxUSD.syncRewardsAndDistribution();

        DeltaStakedFrxUSDStorageSnapshot memory _delta_stakedFrxUSDStorageSnapshot = deltaStakedFrxUSDStorageSnapshot(
            _initial_stakedFrxUSDStorageSnapshot
        );

        //==============================================================================
        // Assert
        //==============================================================================

        /// THEN: lastDistributionTime should be current timestamp
        assertEq(
            _delta_stakedFrxUSDStorageSnapshot.end.lastRewardsDistribution,
            block.timestamp,
            "THEN: lastDistributionTime should be current timestamp"
        );

        /// THEN: lastDistributionTime should have changed by 0
        assertEq(
            _delta_stakedFrxUSDStorageSnapshot.delta.lastRewardsDistribution,
            0,
            "THEN: lastDistributionTime should have changed by 0"
        );

        /// THEN: totalSupply should not have changed
        assertEq(_delta_stakedFrxUSDStorageSnapshot.delta.totalSupply, 0, "THEN: totalSupply should not have changed");

        /// THEN: storedTotalAssets should not have changed
        assertEq(
            _delta_stakedFrxUSDStorageSnapshot.delta.storedTotalAssets,
            0,
            "THEN: storedTotalAssets should not have changed"
        );
    }
}
