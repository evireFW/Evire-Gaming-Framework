// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

contract ProgressionSystem is Initializable, AccessControlUpgradeable, PausableUpgradeable, UUPSUpgradeable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
    using CountersUpgradeable for CountersUpgradeable.Counter;

    bytes32 public constant GAME_MANAGER_ROLE = keccak256("GAME_MANAGER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    struct PlayerData {
        uint256 level;
        uint256 experience;
        EnumerableSetUpgradeable.UintSet achievements;
        mapping(uint256 => uint256) skills; // skill ID => skill level
        uint256 lastUpdateBlock;
    }

    struct Achievement {
        string name;
        string description;
        uint256 experienceReward;
    }

    struct Skill {
        string name;
        uint256 maxLevel;
    }

    mapping(address => PlayerData) private players;
    mapping(uint256 => Achievement) public achievements;
    mapping(uint256 => Skill) public skills;

    CountersUpgradeable.Counter private achievementCounter;
    CountersUpgradeable.Counter private skillCounter;

    uint256 public constant MAX_LEVEL = 100;
    uint256 public constant XP_PER_LEVEL = 1000;

    event LevelUp(address indexed player, uint256 newLevel);
    event ExperienceGained(address indexed player, uint256 amount);
    event AchievementUnlocked(address indexed player, uint256 achievementId);
    event SkillImproved(address indexed player, uint256 skillId, uint256 newLevel);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(GAME_MANAGER_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
    }

    function addExperience(address _player, uint256 _amount) external onlyRole(GAME_MANAGER_ROLE) whenNotPaused {
        PlayerData storage player = players[_player];
        player.experience += _amount;

        uint256 newLevel = (player.experience / XP_PER_LEVEL) + 1;
        if (newLevel > player.level && newLevel <= MAX_LEVEL) {
            player.level = newLevel;
            emit LevelUp(_player, newLevel);
        }

        player.lastUpdateBlock = block.number;
        emit ExperienceGained(_player, _amount);
    }

    function unlockAchievement(address _player, uint256 _achievementId) external onlyRole(GAME_MANAGER_ROLE) whenNotPaused {
        require(_achievementId < achievementCounter.current(), "Invalid achievement ID");
        PlayerData storage player = players[_player];
        require(!player.achievements.contains(_achievementId), "Achievement already unlocked");

        player.achievements.add(_achievementId);
        addExperience(_player, achievements[_achievementId].experienceReward);

        player.lastUpdateBlock = block.number;
        emit AchievementUnlocked(_player, _achievementId);
    }

    function improveSkill(address _player, uint256 _skillId) external onlyRole(GAME_MANAGER_ROLE) whenNotPaused {
        require(_skillId < skillCounter.current(), "Invalid skill ID");
        PlayerData storage player = players[_player];
        uint256 currentSkillLevel = player.skills[_skillId];
        require(currentSkillLevel < skills[_skillId].maxLevel, "Skill already at max level");

        player.skills[_skillId] = currentSkillLevel + 1;
        player.lastUpdateBlock = block.number;
        emit SkillImproved(_player, _skillId, currentSkillLevel + 1);
    }

    function createAchievement(string memory _name, string memory _description, uint256 _experienceReward) external onlyRole(GAME_MANAGER_ROLE) {
        uint256 achievementId = achievementCounter.current();
        achievements[achievementId] = Achievement(_name, _description, _experienceReward);
        achievementCounter.increment();
    }

    function createSkill(string memory _name, uint256 _maxLevel) external onlyRole(GAME_MANAGER_ROLE) {
        uint256 skillId = skillCounter.current();
        skills[skillId] = Skill(_name, _maxLevel);
        skillCounter.increment();
    }

    function getPlayerData(address _player) external view returns (
        uint256 level,
        uint256 experience,
        uint256[] memory unlockedAchievements,
        uint256 lastUpdateBlock
    ) {
        PlayerData storage player = players[_player];
        return (
            player.level,
            player.experience,
            player.achievements.values(),
            player.lastUpdateBlock
        );
    }

    function getPlayerSkill(address _player, uint256 _skillId) external view returns (uint256) {
        require(_skillId < skillCounter.current(), "Invalid skill ID");
        return players[_player].skills[_skillId];
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    // TODO: Implement additional features such as:
    // - Skill trees with prerequisites
    // - Time-based progression (e.g., daily quests, cooldowns)
    // - Integration with other game systems (e.g., item crafting, PvP rankings)
    // - Leaderboards for levels and skills
    // - Achievements with multiple tiers or stages
    // - Anti-cheat measures (e.g., rate limiting, anomaly detection)
}