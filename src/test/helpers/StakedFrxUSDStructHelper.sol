// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "../../contracts/StakedFrxUSD.sol";

library StakedFrxUSDStructHelper {
    function __rewardsCycleData(
        StakedFrxUSD _stakedFrxUSD
    ) internal view returns (StakedFrxUSD.RewardsCycleData memory _return) {
        (_return.cycleEnd, _return.lastSync, _return.rewardCycleAmount) = _stakedFrxUSD.rewardsCycleData();
    }
}
