//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { ERC20Permit, ERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { StorageSlot } from "@openzeppelin/contracts/utils/StorageSlot.sol";

/// @title FrxUSD
/**
 * @notice Combines Openzeppelin's ERC20Permit, ERC20Burnable and Ownable2Step.
 *     Also includes a list of authorized minters
 */
/// @dev FrxUSD adheres to EIP-712/EIP-2612 and can use permits
contract FrxUSD is ERC20Permit, ERC20Burnable, Ownable2Step {
    /// @notice Array of the non-bridge minters
    address[] public minters_array;

    /// @notice Mapping of the minters
    /// @dev Mapping is used for faster verification
    mapping(address => bool) public minters;

    /* ========== CONSTRUCTOR ========== */
    /// @param _ownerAddress The initial owner
    /// @param _name ERC20 name
    /// @param _symbol ERC20 symbol
    constructor(
        address _ownerAddress,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) ERC20Permit(_name) Ownable(_ownerAddress) {}

    /* ========== INITIALIZER ========== */
    /// @dev Used to initialize the contract when it is behind a proxy
    function initialize(address _owner, string memory _name, string memory _symbol) public {
        require(owner() == address(0), "Already initialized");
        _transferOwnership(_owner);
        StorageSlot.getBytesSlot(bytes32(uint256(3))).value = bytes(_name);
        StorageSlot.getBytesSlot(bytes32(uint256(4))).value = bytes(_symbol);
    }

    /* ========== MODIFIERS ========== */

    /// @notice A modifier that only allows a minters to call
    modifier onlyMinters() {
        require(minters[msg.sender] == true, "Only minters");
        _;
    }

    /* ========== RESTRICTED FUNCTIONS [MINTERS] ========== */

    /// @notice Used by minters to burn tokens
    /// @param b_address Address of the account to burn from
    /// @param b_amount Amount of tokens to burn
    function minter_burn_from(address b_address, uint256 b_amount) public onlyMinters {
        super.burnFrom(b_address, b_amount);
        emit TokenMinterBurned(b_address, msg.sender, b_amount);
    }

    /// @notice Used by minters to mint new tokens
    /// @param m_address Address of the account to mint to
    /// @param m_amount Amount of tokens to mint
    function minter_mint(address m_address, uint256 m_amount) public onlyMinters {
        super._mint(m_address, m_amount);
        emit TokenMinterMinted(msg.sender, m_address, m_amount);
    }

    /* ========== RESTRICTED FUNCTIONS [OWNER] ========== */
    /// @notice Adds a minter
    /// @param minter_address Address of minter to add
    function addMinter(address minter_address) public onlyOwner {
        require(minter_address != address(0), "Zero address detected");

        require(minters[minter_address] == false, "Address already exists");
        minters[minter_address] = true;
        minters_array.push(minter_address);

        emit MinterAdded(minter_address);
    }

    /// @notice Removes a non-bridge minter
    /// @param minter_address Address of minter to remove
    function removeMinter(address minter_address) public onlyOwner {
        require(minter_address != address(0), "Zero address detected");
        require(minters[minter_address] == true, "Address nonexistant");

        // Delete from the mapping
        delete minters[minter_address];

        // 'Delete' from the array by setting the address to 0x0
        for (uint256 i = 0; i < minters_array.length; i++) {
            if (minters_array[i] == minter_address) {
                minters_array[i] = address(0); // This will leave a null in the array and keep the indices the same
                break;
            }
        }

        emit MinterRemoved(minter_address);
    }

    /* ========== EVENTS ========== */

    /// @notice Emitted whenever the bridge burns tokens from an account
    /// @param account Address of the account tokens are being burned from
    /// @param amount  Amount of tokens burned
    event Burn(address indexed account, uint256 amount);

    /// @notice Emitted whenever the bridge mints tokens to an account
    /// @param account Address of the account tokens are being minted for
    /// @param amount  Amount of tokens minted.
    event Mint(address indexed account, uint256 amount);

    /// @notice Emitted when a non-bridge minter is added
    /// @param minter_address Address of the new minter
    event MinterAdded(address minter_address);

    /// @notice Emitted when a non-bridge minter is removed
    /// @param minter_address Address of the removed minter
    event MinterRemoved(address minter_address);

    /// @notice Emitted when a non-bridge minter burns tokens
    /// @param from The account whose tokens are burned
    /// @param to The minter doing the burning
    /// @param amount Amount of tokens burned
    event TokenMinterBurned(address indexed from, address indexed to, uint256 amount);

    /// @notice Emitted when a non-bridge minter mints tokens
    /// @param from The minter doing the minting
    /// @param to The account that gets the newly minted tokens
    /// @param amount Amount of tokens minted
    event TokenMinterMinted(address indexed from, address indexed to, uint256 amount);
}
