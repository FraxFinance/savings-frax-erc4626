// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "./BaseTestStakedFrxUSD.sol";

abstract contract StakedFrxUSDFunctions is BaseTestStakedFrxUSD {
    function _stakedFrxUSD_setMaxDistributionPerSecondPerAsset(uint256 _maxDistributionPerSecondPerAsset) internal {
        hoax(stakedFrxUSD.timelockAddress());
        stakedFrxUSD.setMaxDistributionPerSecondPerAsset(_maxDistributionPerSecondPerAsset);
    }
}

contract TestSetMaxDistributionPerSecondPerAsset is BaseTestStakedFrxUSD, StakedFrxUSDFunctions {
    /// FEATURE: setMaxDistributionPerSecondPerAsset

    function setUp() public {
        /// BACKGROUND: deploy the StakedFrxUSD contract
        /// BACKGROUND: 10% APY cap
        /// BACKGROUND: frax as the underlying asset
        /// BACKGROUND: TIMELOCK_ADDRESS set as the timelock address
        defaultSetup();
    }

    function test_CannotCallIfNotTimelock() public {
        /// WHEN: non-timelock calls setMaxDistributionPerSecondPerAsset
        vm.expectRevert(
            abi.encodeWithSelector(
                Timelock2Step.AddressIsNotTimelock.selector,
                stakedFrxUSD.timelockAddress(),
                address(this)
            )
        );
        stakedFrxUSD.setMaxDistributionPerSecondPerAsset(1 ether);
        /// THEN: we expect a revert with the AddressIsNotTimelock error
    }

    function test_CannotSetAboveUint64() public {
        StakedFrxUSDStorageSnapshot memory _initial_stakedFrxUSDStorageSnapshot = stakedFrxUSDStorageSnapshot(
            stakedFrxUSD
        );

        /// WHEN: timelock sets maxDistributionPerSecondPerAsset to uint64.max + 1
        _stakedFrxUSD_setMaxDistributionPerSecondPerAsset(uint256(type(uint64).max) + 1);

        DeltaStakedFrxUSDStorageSnapshot memory _delta_stakedFrxUSDStorageSnapshot = deltaStakedFrxUSDStorageSnapshot(
            _initial_stakedFrxUSDStorageSnapshot
        );

        /// THEN: values should be equal to uint64.max
        assertEq(
            _delta_stakedFrxUSDStorageSnapshot.end.maxDistributionPerSecondPerAsset,
            type(uint64).max,
            "THEN: values should be equal to uint64.max"
        );
    }

    function test_CanSetMaxDistributionPerSecondPerAsset() public {
        StakedFrxUSDStorageSnapshot memory _initial_stakedFrxUSDStorageSnapshot = stakedFrxUSDStorageSnapshot(
            stakedFrxUSD
        );

        /// WHEN: timelock sets maxDistributionPerSecondPerAsset to 1 ether
        _stakedFrxUSD_setMaxDistributionPerSecondPerAsset(1 ether);

        DeltaStakedFrxUSDStorageSnapshot memory _delta_stakedFrxUSDStorageSnapshot = deltaStakedFrxUSDStorageSnapshot(
            _initial_stakedFrxUSDStorageSnapshot
        );

        /// THEN: maxDistributionPerSecondPerAsset should be 1 ether
        assertEq(
            _delta_stakedFrxUSDStorageSnapshot.end.maxDistributionPerSecondPerAsset,
            1 ether,
            "THEN: maxDistributionPerSecondPerAsset should be 1 ether"
        );
    }
}
