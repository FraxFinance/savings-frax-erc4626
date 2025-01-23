// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "frax-std/FraxTest.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { FrxUSD } from "../../contracts/FrxUSD.sol";
import { FrxUSDCustodian } from "../../contracts/FrxUSDCustodian.sol";
import { FrxUSDCustodianFactory } from "../../contracts/FrxUSDCustodianFactory.sol";
import "../../Constants.sol" as Constants;

contract FrxUSDCustodianForkTest is FraxTest {
    address constant frxUSDCustodian = 0x3c2f8c81c24C1c2Acd330290431863A90f092E91;
    address constant FRXUSD = 0xCAcd6fd266aF91b8AeD52aCCc382b4e165586E29;
    IERC20 public legacyFRAX = IERC20(0x853d955aCEf822Db058eb8505911ED77F175b99e);

    function test_FrxUSDCustodian() public {
        vm.createSelectFork(vm.envString("MAINNET_URL"), 21_667_632);
        address whale = 0x5E583B6a1686f7Bc09A6bBa66E852A7C80d36F00;
        FrxUSDCustodian custContract = FrxUSDCustodian(frxUSDCustodian);
        vm.startPrank(whale);
        legacyFRAX.approve(frxUSDCustodian, 1_000_000e18);
        vm.expectRevert(); // Not yet minter
        custContract.mint(100e18, whale);
        vm.stopPrank();

        vm.startPrank(Constants.Mainnet.FRAX_ERC20_OWNER);
        FrxUSD(FRXUSD).addMinter(frxUSDCustodian);
        vm.stopPrank();

        vm.startPrank(whale);
        custContract.mint(100e18, whale);
        custContract.mint(99_900e18, whale);
        vm.expectRevert(); // At mint cap
        custContract.mint(1e18, whale);
        IERC20(FRXUSD).approve(frxUSDCustodian, 100_000e18);
        custContract.redeem(100_000e18, whale, whale);
        vm.stopPrank();
    }
}
