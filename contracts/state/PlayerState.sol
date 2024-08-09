// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract PlayerState is AccessControl, Pausable, ReentrancyGuard {
    using Counters for Counters.Counter;

    bytes32 public constant GAME_MANAGER_ROLE = keccak256("GAME_MANAGER_ROLE");
    bytes32 public constant PLAYER_ADMIN_ROLE = keccak256("PLAYER_ADMIN_ROLE");

    Counters.Counter private _playerIds;

    struct Player {
        uint256 id;
        address account;
        uint256 level;
        uint256 experience;
        uint256 health;
        uint256 mana;
        uint256 energy;
        uint256[] inventory;
        mapping(bytes32 => uint256) attributes; 
    }

    mapping(uint256 => Player) private _players;
    mapping(address => uint256) private _playerIdsByAccount;

    event PlayerCreated(uint256 indexed playerId, address indexed account);
    event PlayerLevelUp(uint256 indexed playerId, uint256 newLevel);
    event PlayerExperienceGained(uint256 indexed playerId, uint256 experience);
    event PlayerHealthUpdated(uint256 indexed playerId, uint256 newHealth);
    event PlayerManaUpdated(uint256 indexed playerId, uint256 newMana);
    event PlayerEnergyUpdated(uint256 indexed playerId, uint256 newEnergy);
    event PlayerInventoryUpdated(uint256 indexed playerId, uint256[] inventory);
    event PlayerAttributeUpdated(uint256 indexed playerId, bytes32 indexed attributeKey, uint256 newValue);

    modifier onlyPlayerAdmin() {
        require(hasRole(PLAYER_ADMIN_ROLE, msg.sender), "PlayerState: caller is not a player admin");
        _;
    }

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(GAME_MANAGER_ROLE, msg.sender);
        _setupRole(PLAYER_ADMIN_ROLE, msg.sender);
    }

    function createPlayer(address account) external onlyRole(GAME_MANAGER_ROLE) whenNotPaused nonReentrant returns (uint256) {
        require(_playerIdsByAccount[account] == 0, "PlayerState: Player already exists for this account");

        _playerIds.increment();
        uint256 newPlayerId = _playerIds.current();

        Player storage newPlayer = _players[newPlayerId];
        newPlayer.id = newPlayerId;
        newPlayer.account = account;
        newPlayer.level = 1;
        newPlayer.experience = 0;
        newPlayer.health = 100;
        newPlayer.mana = 100;
        newPlayer.energy = 100;

        _playerIdsByAccount[account] = newPlayerId;

        emit PlayerCreated(newPlayerId, account);

        return newPlayerId;
    }

    function levelUp(uint256 playerId) external onlyPlayerAdmin whenNotPaused nonReentrant {
        Player storage player = _players[playerId];
        player.level++;
        emit PlayerLevelUp(playerId, player.level);
    }

    function gainExperience(uint256 playerId, uint256 experience) external onlyPlayerAdmin whenNotPaused nonReentrant {
        Player storage player = _players[playerId];
        player.experience += experience;
        emit PlayerExperienceGained(playerId, experience);
    }

    function updateHealth(uint256 playerId, uint256 health) external onlyPlayerAdmin whenNotPaused nonReentrant {
        Player storage player = _players[playerId];
        player.health = health;
        emit PlayerHealthUpdated(playerId, health);
    }

    function updateMana(uint256 playerId, uint256 mana) external onlyPlayerAdmin whenNotPaused nonReentrant {
        Player storage player = _players[playerId];
        player.mana = mana;
        emit PlayerManaUpdated(playerId, mana);
    }

    function updateEnergy(uint256 playerId, uint256 energy) external onlyPlayerAdmin whenNotPaused nonReentrant {
        Player storage player = _players[playerId];
        player.energy = energy;
        emit PlayerEnergyUpdated(playerId, energy);
    }

    function updateInventory(uint256 playerId, uint256[] calldata inventory) external onlyPlayerAdmin whenNotPaused nonReentrant {
        Player storage player = _players[playerId];
        player.inventory = inventory;
        emit PlayerInventoryUpdated(playerId, inventory);
    }

    function updateAttribute(uint256 playerId, bytes32 attributeKey, uint256 newValue) external onlyPlayerAdmin whenNotPaused nonReentrant {
        Player storage player = _players[playerId];
        player.attributes[attributeKey] = newValue;
        emit PlayerAttributeUpdated(playerId, attributeKey, newValue);
    }

    function getPlayerById(uint256 playerId) external view returns (Player memory) {
        return _players[playerId];
    }

    function getPlayerByAccount(address account) external view returns (Player memory) {
        uint256 playerId = _playerIdsByAccount[account];
        require(playerId != 0, "PlayerState: No player found for this account");
        return _players[playerId];
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
