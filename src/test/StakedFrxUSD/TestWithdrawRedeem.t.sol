// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "./BaseTestStakedFrxUSD.sol";
import { StakedFrxUSDFunctions } from "./TestSetMaxDistributionPerSecondPerAsset.t.sol";
import { mintDepositFunctions } from "./TestMintAndDeposit.t.sol";

abstract contract RedeemWithdrawFunctions is BaseTestStakedFrxUSD {
    function _stakedFrxUSD_redeem(uint256 _shares, address _recipient) internal {
        hoax(_recipient);
        stakedFrxUSD.redeem(_shares, _recipient, _recipient);
    }

    function _stakedFrxUSD_withdraw(uint256 _assets, address _recipient) internal {
        hoax(_recipient);
        stakedFrxUSD.withdraw(_assets, _recipient, _recipient);
    }
}

contract TestRedeemAndWithdrawStakedFrxUSD is
    BaseTestStakedFrxUSD,
    StakedFrxUSDFunctions,
    mintDepositFunctions,
    RedeemWithdrawFunctions
{
    /// FEATURE: redeem and withdraw

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

    function test_RedeemAllWithUnCappedRewards() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: totalSupply is 1000
        assertEq(stakedFrxUSD.totalSupply(), 1000 ether, "setup:totalSupply should be 1000");

        /// GIVEN: storedTotalAssets is 1000
        assertEq(
            stakedFrxUSD.storedTotalAssets(),
            (1000e18 * stakedFrxUSD.pricePerShare()) / 1e18,
            "setup: storedTotalAssets should be 1000*PricePerShare"
        );

        /// GIVEN: maxDistributionPerSecondPerAsset is uncapped
        uint256 _maxDistributionPerSecondPerAsset = type(uint256).max;
        _stakedFrxUSD_setMaxDistributionPerSecondPerAsset(_maxDistributionPerSecondPerAsset);

        /// GIVEN: timestamp is 400_000 seconds away from the end of the cycle
        uint256 _syncDuration = 400_000;
        mineBlocksToTimestamp(stakedFrxUSD.__rewardsCycleData().cycleEnd + rewardsCycleLength - _syncDuration);

        /// GIVEN: 600 FRAX is transferred as rewards
        uint256 _rewards = 600 ether;
        mintFraxTo(stakedFrxUSDAddress, _rewards);

        /// GIVEN: syncAndDistributeRewards is called
        stakedFrxUSD.syncRewardsAndDistribution();

        /// GIVEN: bob deposits 1000 FRAX
        _stakedFrxUSD_deposit(1000 ether, bob);

        /// GIVEN: We wait 100_000 seconds
        uint256 _timeSinceLastRewardsDistribution = 100_000;
        mineBlocksBySecond(_timeSinceLastRewardsDistribution);

        //==============================================================================
        // Act
        //==============================================================================

        StakedFrxUSDStorageSnapshot memory _initial_stakedFrxUSDStorageSnapshot = stakedFrxUSDStorageSnapshot(
            stakedFrxUSD
        );

        UserStorageSnapshot memory _initial_bobStorageSnapshot = userStorageSnapshot(bob, stakedFrxUSD);

        /// WHEN: bob redeems all of his FRAX
        uint256 _shares = stakedFrxUSD.balanceOf(bob);
        _stakedFrxUSD_redeem(_shares, bob);

        DeltaStakedFrxUSDStorageSnapshot memory _delta_stakedFrxUSDStorageSnapshot = deltaStakedFrxUSDStorageSnapshot(
            _initial_stakedFrxUSDStorageSnapshot
        );

        DeltaUserStorageSnapshot memory _delta_bobStorageSnapshot = deltaUserStorageSnapshot(
            _initial_bobStorageSnapshot
        );

        //==============================================================================
        // Assert
        //==============================================================================

        assertEq({
            err: "THEN: totalSupply should decrease by _shares",
            a: _delta_stakedFrxUSDStorageSnapshot.delta.totalSupply,
            b: _shares
        });
        assertLt({
            err: "THEN: totalSupply should decrease",
            a: _delta_stakedFrxUSDStorageSnapshot.end.totalSupply,
            b: _delta_stakedFrxUSDStorageSnapshot.start.totalSupply
        });

        console.log("_shares", _shares);
        console.log(
            _delta_stakedFrxUSDStorageSnapshot.start.storedTotalAssets,
            _delta_stakedFrxUSDStorageSnapshot.end.storedTotalAssets
        );
        console.log(
            _delta_stakedFrxUSDStorageSnapshot.start.totalSupply,
            _delta_stakedFrxUSDStorageSnapshot.end.totalSupply
        );

        uint256 _expectedWithdrawAmount = (_shares * stakedFrxUSD.pricePerShare()) / 1e18;
        uint256 _expectedRewards = 600 ether / 4;
        assertApproxEqAbs({
            err: "THEN: totalStored assets should change by +150 for rewards and -1125 for redeem",
            a: _delta_stakedFrxUSDStorageSnapshot.delta.storedTotalAssets,
            b: _expectedWithdrawAmount - _expectedRewards,
            maxDelta: 1
        });

        assertEq({
            err: "THEN: bob's balance should be 0",
            a: _delta_bobStorageSnapshot.end.stakedFrxUSD.balanceOf,
            b: 0
        });
        /*assertEq({
            err: "THEN: bob's frax balance should have changed by 1075 (1000 + 75 rewards)",
            a: _delta_bobStorageSnapshot.delta.asset.balanceOf,
            b: 1075 ether
        });*/
    }

    function test_WithdrawWithUnCappedRewards() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: totalSupply is 1000
        assertEq(stakedFrxUSD.totalSupply(), 1000 ether, "setup:totalSupply should be 1000");

        /// GIVEN: storedTotalAssets is 1000
        assertEq(
            stakedFrxUSD.storedTotalAssets(),
            (1000e18 * stakedFrxUSD.pricePerShare()) / 1e18,
            "setup: storedTotalAssets should be 1000*PricePerShare"
        );

        /// GIVEN: maxDistributionPerSecondPerAsset is uncapped
        uint256 _maxDistributionPerSecondPerAsset = type(uint256).max;
        _stakedFrxUSD_setMaxDistributionPerSecondPerAsset(_maxDistributionPerSecondPerAsset);

        /// GIVEN: timestamp is 400_000 seconds away from the end of the cycle
        uint256 _syncDuration = 400_000;
        mineBlocksToTimestamp(stakedFrxUSD.__rewardsCycleData().cycleEnd + rewardsCycleLength - _syncDuration);

        /// GIVEN: 600 FRAX is transferred as rewards
        uint256 _rewards = 600 ether;
        mintFraxTo(stakedFrxUSDAddress, _rewards);

        /// GIVEN: syncAndDistributeRewards is called
        stakedFrxUSD.syncRewardsAndDistribution();

        uint256 _expectedDepositShares = (1000e18 * 1e18) / stakedFrxUSD.pricePerShare();

        /// GIVEN: bob deposits 1000 FRAX
        _stakedFrxUSD_deposit(1000 ether, bob);

        /// GIVEN: We wait 100_000 seconds
        uint256 _timeSinceLastRewardsDistribution = 100_000;
        mineBlocksBySecond(_timeSinceLastRewardsDistribution);

        //==============================================================================
        // Act
        //==============================================================================

        StakedFrxUSDStorageSnapshot memory _initial_stakedFrxUSDStorageSnapshot = stakedFrxUSDStorageSnapshot(
            stakedFrxUSD
        );

        UserStorageSnapshot memory _initial_bobStorageSnapshot = userStorageSnapshot(bob, stakedFrxUSD);

        /// WHEN: bob withdraws 1000 frax
        _stakedFrxUSD_withdraw(1000 ether, bob);

        DeltaStakedFrxUSDStorageSnapshot memory _delta_stakedFrxUSDStorageSnapshot = deltaStakedFrxUSDStorageSnapshot(
            _initial_stakedFrxUSDStorageSnapshot
        );

        DeltaUserStorageSnapshot memory _delta_bobStorageSnapshot = deltaUserStorageSnapshot(
            _initial_bobStorageSnapshot
        );

        //==============================================================================
        // Assert
        //==============================================================================

        uint256 _expectedShares = (1000e18 * 1e18) / stakedFrxUSD.pricePerShare();
        assertApproxEqAbs({
            err: "/// THEN: totalSupply should decrease by 1000/pricePerShare",
            a: _delta_stakedFrxUSDStorageSnapshot.delta.totalSupply,
            b: _expectedShares,
            maxDelta: 1
        });
        assertLt({
            err: "/// THEN: totalSupply should decrease",
            a: _delta_stakedFrxUSDStorageSnapshot.end.totalSupply,
            b: _delta_stakedFrxUSDStorageSnapshot.start.totalSupply
        });
        assertEq({
            err: "/// THEN: totalStored assets should change by -1000 +150 for rewards",
            a: _delta_stakedFrxUSDStorageSnapshot.delta.storedTotalAssets,
            b: 850e18
        });
        console.log("stakedFrxUSD.balanceOf(bob)", stakedFrxUSD.balanceOf(bob));
        assertApproxEqAbs({
            err: "/// THEN: bob's balance should be 1000 - _expectedShares",
            a: _delta_bobStorageSnapshot.end.stakedFrxUSD.balanceOf,
            b: (_expectedDepositShares - _expectedShares),
            maxDelta: 1000
        });
        assertApproxEqAbs({
            err: "/// THEN: bob's staked frax balance should have changed by _expectedShares",
            a: _delta_bobStorageSnapshot.delta.stakedFrxUSD.balanceOf,
            b: _expectedShares,
            maxDelta: 1
        });
        assertEq({
            err: "/// THEN: bob's frax balance should have changed by 1000",
            a: _delta_bobStorageSnapshot.delta.asset.balanceOf,
            b: 1000 ether
        });
    }

    function test_CanWithdrawWhenSyncedOnCycleEnd() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: totalSupply is 1000
        assertEq(stakedFrxUSD.totalSupply(), 1000 ether, "setup:totalSupply should be 1000");

        /// GIVEN: storedTotalAssets is 1000
        assertEq(
            stakedFrxUSD.storedTotalAssets(),
            (1000e18 * stakedFrxUSD.pricePerShare()) / 1e18,
            "setup: storedTotalAssets should be 1000*PricePerShare"
        );

        /// GIVEN: maxDistributionPerSecondPerAsset is uncapped
        uint256 _maxDistributionPerSecondPerAsset = type(uint256).max;
        _stakedFrxUSD_setMaxDistributionPerSecondPerAsset(_maxDistributionPerSecondPerAsset);

        /// GIVEN: timestamp is 400_000 seconds away from the end of the cycle
        uint256 _syncDuration = 400_000;
        mineBlocksToTimestamp(stakedFrxUSD.__rewardsCycleData().cycleEnd + rewardsCycleLength - _syncDuration);

        /// GIVEN: 600 FRAX is transferred as rewards
        uint256 _rewards = 600 ether;
        mintFraxTo(stakedFrxUSDAddress, _rewards);

        /// GIVEN: syncAndDistributeRewards is called
        stakedFrxUSD.syncRewardsAndDistribution();

        /// GIVEN: bob deposits 1000 FRAX
        _stakedFrxUSD_deposit(1000 ether, bob);

        /// GIVEN: We wait until timestamp == cycle end
        mineBlocksToTimestamp(stakedFrxUSD.__rewardsCycleData().cycleEnd);

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: bob withdraws 1000 frax
        _stakedFrxUSD_withdraw(1000 ether, bob);
    }
}
