// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "frax-std/FraxTest.sol";
import "../../contracts/FrxUSD.sol";
import "../../script/DeployFrxUSD.s.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract TestFrxUSD is FraxTest {
    FrxUSD public frxUSD;

    function setUp() public {
        DeployProxyAndFrxUSD deployerContract = new DeployProxyAndFrxUSD();
        frxUSD = FrxUSD(deployerContract.deployProxyAndFrxUSD());
    }

    function test_Deploy() public {
        address implementation = address(
            uint160(
                uint256(vm.load(address(frxUSD), 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc))
            )
        );
        console.log("FrxUSD implementation address: ", implementation);
        FrxUSD frxUSDImplementation = FrxUSD(implementation);
        for (uint256 i = 0; i < 20; i++) {
            require(
                vm.load(address(frxUSD), bytes32(i)) == vm.load(address(frxUSDImplementation), bytes32(i)),
                "Storage slot mismatch"
            );
        }
        vm.expectRevert("Already initialized");
        frxUSD.initialize(Constants.Mainnet.FRAX_ERC20_OWNER, "NewName", "NewSymbol");

        vm.expectRevert("Already initialized");
        FrxUSD(implementation).initialize(Constants.Mainnet.FRAX_ERC20_OWNER, "NewName", "NewSymbol");

        require(frxUSD.owner() == Constants.Mainnet.FRAX_ERC20_OWNER, "Owner mismatch");
        require(keccak256(bytes(frxUSD.name())) == keccak256("Frax USD"), "Name mismatch");
        require(keccak256(bytes(frxUSD.symbol())) == keccak256("frxUSD"), "Name mismatch");
        require(frxUSD.totalSupply() == 0, "totalSupply mismatch");
    }

    function test_Mint() public {
        // Only minters can mint
        vm.expectRevert("Only minters");
        frxUSD.minter_mint(address(this), 1000);

        // Only owner can add minters
        vm.expectRevert();
        frxUSD.addMinter(address(this));

        // Owner can add minters
        vm.startPrank(frxUSD.owner());
        frxUSD.addMinter(address(this));
        vm.stopPrank();

        // Minters can mint
        frxUSD.minter_mint(address(this), 1000);
        require(frxUSD.balanceOf(address(this)) == 1000, "Balance mismatch");
        require(frxUSD.totalSupply() == 1000, "totalSupply mismatch");

        // Only owner can remove minters
        vm.expectRevert();
        frxUSD.removeMinter(address(this));

        // owner can remove minters
        vm.startPrank(frxUSD.owner());
        frxUSD.removeMinter(address(this));
        vm.stopPrank();

        // Removed minters can't mint
        vm.expectRevert("Only minters");
        frxUSD.minter_mint(address(this), 1000);
    }

    function test_Burn() public {
        // Mint some tokens
        vm.startPrank(frxUSD.owner());
        frxUSD.addMinter(address(this));
        vm.stopPrank();
        frxUSD.minter_mint(address(this), 1000);

        // Can only burn with allowance
        vm.expectRevert();
        frxUSD.minter_burn_from(address(this), 1000);

        // Can burn with allowance
        frxUSD.approve(address(this), 1000);
        frxUSD.minter_burn_from(address(this), 1000);

        require(frxUSD.totalSupply() == 0, "Total supply mismatch");
    }

    function test_Proxy() public {
        // Mint some tokens
        vm.startPrank(frxUSD.owner());
        frxUSD.addMinter(address(this));
        vm.stopPrank();
        frxUSD.minter_mint(address(this), 1000);

        // Check that the proxy is set up correctly
        address implementation = address(
            uint160(
                uint256(vm.load(address(frxUSD), 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc))
            )
        );
        address proxyAdmin = address(
            uint160(
                uint256(vm.load(address(frxUSD), 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103))
            )
        );
        address proxyOwner = ProxyAdmin(proxyAdmin).owner();
        require(proxyOwner == Constants.Mainnet.FRAX_ERC20_OWNER, "Proxy owner mismatch");

        // Deploy a new implementation
        NewImplementationFrxUSD newImplementation = new NewImplementationFrxUSD(
            Constants.Mainnet.FRAX_ERC20_OWNER,
            "NewName",
            "NewSymbol"
        );
        address newImplementationAddress = address(newImplementation);

        // Only the proxy admin can upgrade the proxy
        vm.expectRevert();
        ProxyAdmin(proxyAdmin).upgradeAndCall(
            ITransparentUpgradeableProxy(address(frxUSD)),
            newImplementationAddress,
            ""
        );

        // Upgrade the proxy
        vm.startPrank(proxyOwner);
        ProxyAdmin(proxyAdmin).upgradeAndCall(
            ITransparentUpgradeableProxy(address(frxUSD)),
            newImplementationAddress,
            ""
        );
        vm.stopPrank();

        address newStoredImplementation = address(
            uint160(
                uint256(vm.load(address(frxUSD), 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc))
            )
        );
        require(newImplementationAddress == newStoredImplementation, "Implementation mismatch");

        vm.expectEmit();
        emit NewImplementationFrxUSD.TransferOverride(address(this), address(this), 1000);
        frxUSD.transfer(address(this), 1000);
    }
}

contract NewImplementationFrxUSD is FrxUSD {
    constructor(
        address _ownerAddress,
        string memory _name,
        string memory _symbol
    ) FrxUSD(_ownerAddress, _name, _symbol) {}

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        bool result = super.transfer(recipient, amount);
        emit TransferOverride(msg.sender, recipient, amount);
        return result;
    }

    event TransferOverride(address indexed from, address indexed to, uint256 value);
}
