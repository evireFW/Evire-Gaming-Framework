// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title EvireToken
 * @dev ERC20 token for the Evire gaming framework, supporting features like pausing, minting, burning, snapshots and capped supply.
 */

contract EvireToken is ERC20, ERC20Burnable, ERC20Capped, ERC20Snapshot, Pausable, AccessControl, ReentrancyGuard {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant SNAPSHOT_ROLE = keccak256("SNAPSHOT_ROLE");

    uint256 private constant _initialSupply = 1e24; // 1 million tokens with 18 decimals

    event TokensRecovered(address indexed token, address indexed to, uint256 amount);

    constructor(
        string memory name,
        string memory symbol,
        uint256 cap
    ) ERC20(name, symbol) ERC20Capped(cap) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
        _setupRole(SNAPSHOT_ROLE, msg.sender);

        _mint(msg.sender, _initialSupply);
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        require(totalSupply() + amount <= cap(), "EvireToken: cap exceeded");
        _mint(to, amount);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function snapshot() public onlyRole(SNAPSHOT_ROLE) returns (uint256) {
        return _snapshot();
    }

    function recoverERC20(address tokenAddress, address to, uint256 amount) public onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        require(tokenAddress != address(this), "EvireToken: Cannot recover EvireToken itself");
        IERC20(tokenAddress).transfer(to, amount);
        emit TokensRecovered(tokenAddress, to, amount);
    }

    function recoverERC721(address tokenAddress, address to, uint256 tokenId) public onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        IERC721(tokenAddress).safeTransferFrom(address(this), to, tokenId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override(ERC20, ERC20Snapshot) {
        require(!paused() || hasRole(MINTER_ROLE, msg.sender), "EvireToken: token transfer while paused");
        super._beforeTokenTransfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal override(ERC20, ERC20Capped) {
        super._mint(account, amount);
    }

    function _burn(address account, uint256 amount) internal override(ERC20) {
        super._burn(account, amount);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
