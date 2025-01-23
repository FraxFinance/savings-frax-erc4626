// SPDX-License-Identifier: MIT
// @version 0.2.8
pragma solidity >=0.8.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { FrxUSDCustodian } from "./FrxUSDCustodian.sol";

contract FrxUSDCustodianFactory is Ownable2Step {
    /* ========== STATE VARIABLES ========== */

    address public frxUSD;

    /* ========== CONSTRUCTOR ========== */

    constructor(address _owner, address _frxUSD) Ownable(_owner) {
        frxUSD = _frxUSD;
    }

    /* ========== DEPLOYER ========== */
    function deployCustodian(
        address _custodianTkn,
        uint256 _mintCap,
        uint256 _mintFee,
        uint256 _redeemFee
    ) external onlyOwner returns (address _custodianAddr) {
        address _implementation = address(new FrxUSDCustodian(frxUSD, _custodianTkn));
        _custodianAddr = address(new TransparentUpgradeableProxy(address(_implementation), owner(), ""));
        FrxUSDCustodian(_custodianAddr).initialize(owner(), _mintCap, _mintFee, _redeemFee);
        emit CustodianDeployed(_custodianAddr, _custodianTkn, _mintCap, _mintFee, _redeemFee);
    }

    /* ========== EVENTS ========== */

    event CustodianDeployed(
        address indexed custodianAddr,
        address indexed custodianTkn,
        uint256 mintCap,
        uint256 _mintFee,
        uint256 _redeemFee
    );
}
