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
// ========================== FrxUSDMigrator ==========================
// ====================================================================
// Frax Finance: https://github.com/FraxFinance

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { StakedFrax } from "./StakedFrax.sol";
import { StakedFrxUSD } from "./StakedFrxUSD.sol";
import { FrxUSDCustodian } from "./FrxUSDCustodian.sol";

contract FrxUSDMigrator {
    // Addresses
    IERC20 public constant frxUSD = IERC20(0xCAcd6fd266aF91b8AeD52aCCc382b4e165586E29);
    IERC20 public constant frax = IERC20(0x853d955aCEf822Db058eb8505911ED77F175b99e);
    StakedFrxUSD public constant sfrxUSD = StakedFrxUSD(0xcf62F905562626CfcDD2261162a51fd02Fc9c5b6);
    StakedFrax public constant sFRAX = StakedFrax(0xA663B02CF0a4b149d2aD41910CB81e23e1c41c32);
    FrxUSDCustodian public constant frxUSDCustodian = FrxUSDCustodian(0x3c2f8c81c24C1c2Acd330290431863A90f092E91);

    /// @notice Migrate tokens
    /// @param tokenIn The token to deposit
    /// @param tokenOut The token to receive
    /// @param _amount The amount to unmigrate
    /// @return The amount of tokens received
    function migrate(address tokenIn, address tokenOut, uint256 _amount) external returns (uint256) {
        IERC20(tokenIn).transferFrom(msg.sender, address(this), _amount);
        if (tokenIn == address(sFRAX)) {
            address recipient = tokenOut == address(frax) ? msg.sender : address(this);
            _amount = sFRAX.redeem(_amount, recipient, address(this));
            tokenIn = address(frax);
            if (tokenIn == tokenOut) return _amount;
        }
        if (tokenIn == address(frax)) {
            IERC20(tokenIn).approve(address(frxUSDCustodian), _amount);
            address recipient = tokenOut == address(frxUSD) ? msg.sender : address(this);
            _amount = frxUSDCustodian.deposit(_amount, recipient);
            tokenIn = address(frxUSD);
            if (tokenIn == tokenOut) return _amount;
        }
        if (tokenIn == address(frxUSD)) {
            IERC20(tokenIn).approve(address(sfrxUSD), _amount);
            _amount = sfrxUSD.deposit(_amount, msg.sender);
            tokenIn = address(sfrxUSD);
            if (tokenIn == tokenOut) return _amount;
        }
        revert migrationFailed();
    }

    /// @notice Unmigrate tokens
    /// @param tokenIn The token to deposit
    /// @param tokenOut The token to receive
    /// @param _amount The amount to unmigrate
    /// @return The amount of tokens received
    function unmigrate(address tokenIn, address tokenOut, uint256 _amount) external returns (uint256) {
        IERC20(tokenIn).transferFrom(msg.sender, address(this), _amount);
        if (tokenIn == address(sfrxUSD)) {
            address recipient = tokenOut == address(frxUSD) ? msg.sender : address(this);
            _amount = sfrxUSD.redeem(_amount, recipient, address(this));
            tokenIn = address(frxUSD);
            if (tokenIn == tokenOut) return _amount;
        }
        if (tokenIn == address(frxUSD)) {
            IERC20(tokenIn).approve(address(frxUSDCustodian), _amount);
            address recipient = tokenOut == address(frax) ? msg.sender : address(this);
            _amount = frxUSDCustodian.redeem(_amount, recipient, address(this));
            tokenIn = address(frax);
            if (tokenIn == tokenOut) return _amount;
        }
        if (tokenIn == address(frax)) {
            IERC20(tokenIn).approve(address(sFRAX), _amount);
            _amount = sFRAX.deposit(_amount, msg.sender);
            tokenIn = address(sFRAX);
            if (tokenIn == tokenOut) return _amount;
        }
        revert migrationFailed();
    }

    // Error
    error migrationFailed();
}
