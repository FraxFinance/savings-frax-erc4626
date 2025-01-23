// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "./BaseTestStakedFrxUSD.sol";
import "../../contracts/StakedFrax.sol";

contract TestDeploymentSfrxUSD is BaseTestStakedFrxUSD {
    /// FEATURE: deployment script

    using StakedFrxUSDStructHelper for *;

    function setUp() public {
        /// BACKGROUND: deploy the StakedFrxUSD contract
        /// BACKGROUND: 10% APY cap
        /// BACKGROUND: frax as the underlying asset
        /// BACKGROUND: TIMELOCK_ADDRESS set as the timelock address
        defaultSetup();
    }

    function test_Deploy() public {
        StakedFrax stakedFrax = StakedFrax(0xA663B02CF0a4b149d2aD41910CB81e23e1c41c32);

        /// SCENARIO: The deployment is as expected after the deploy script is used

        /// WHEN: StakedFrxUSD contract is deployed

        /// THEN: A totalSupply of Shares is 1000
        assertEq(stakedFrxUSD.totalSupply(), 1000 ether, "setup:totalSupply should be 1000");

        /// THEN: storedTotalAssets is 1000
        assertEq(
            stakedFrxUSD.storedTotalAssets(),
            ((1000 ether) * stakedFrax.pricePerShare()) / 1e18,
            "setup: storedTotalAssets should be 1000"
        );

        /// THEN: cycleEnd next full cycle multiplied from unix epoch
        assertEq(
            stakedFrxUSD.__rewardsCycleData().cycleEnd,
            ((block.timestamp + rewardsCycleLength) / rewardsCycleLength) * rewardsCycleLength,
            "setup: cycleEnd should be next full cycle multiplied from unix epoch"
        );

        (uint40 _cycleEnd, uint40 _lastSync, uint216 _rewardCycleAmount) = stakedFrax.rewardsCycleData();

        /// THEN: lastSync is same as sFRAX
        assertEq(
            stakedFrxUSD.__rewardsCycleData().lastSync,
            _lastSync,
            "setup: lastSync should be equal to lastSync of sFRAX"
        );

        /// THEN: _cycleEnd is same as sFRAX
        assertEq(
            stakedFrxUSD.__rewardsCycleData().cycleEnd,
            _cycleEnd,
            "setup: cycleEnd should be equal to cycleEnd of sFRAX"
        );

        /*/// THEN: rewardsForDistribution is same as sFRAX
        assertEq(stakedFrxUSD.__rewardsCycleData().rewardCycleAmount, _rewardCycleAmount, "setup: rewardsForDistribution should be equal to rewardsForDistribution of sFRAX");*/

        /// THEN: lastDistributionTime is same as sFRAX
        assertEq(
            stakedFrxUSD.lastRewardsDistribution(),
            stakedFrax.lastRewardsDistribution(),
            "setup: lastDistributionTime should be equal to lastDistributionTime of sFRAX"
        );

        /// THEN: rewardsCycleLength is 7 days
        assertEq(stakedFrxUSD.REWARDS_CYCLE_LENGTH(), 7 days, "setup: rewardsCycleLength should be 7 days");

        /// THEN: maxDistributionPerSecondPerAsset is ame as sFRAX
        assertEq(
            stakedFrxUSD.maxDistributionPerSecondPerAsset(),
            stakedFrax.maxDistributionPerSecondPerAsset(),
            "setup: maxDistributionPerSecondPerAsset should be equal to maxDistributionPerSecondPerAsset of sFRAX"
        );
    }
}
