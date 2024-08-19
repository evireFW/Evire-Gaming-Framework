// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

contract LeaderboardSystem is Initializable, AccessControlUpgradeable, PausableUpgradeable, UUPSUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    bytes32 public constant GAME_MANAGER_ROLE = keccak256("GAME_MANAGER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    struct PlayerScore {
        address playerAddress;
        uint256 score;
        uint256 lastUpdated;
    }

    struct Leaderboard {
        string name;
        PlayerScore[] topScores;
        uint256 maxEntries;
        mapping(address => uint256) playerRanks;
        bool exists;
    }

    mapping(uint256 => Leaderboard) private leaderboards;
    CountersUpgradeable.Counter private leaderboardCounter;

    event LeaderboardCreated(uint256 indexed leaderboardId, string name, uint256 maxEntries);
    event ScoreUpdated(uint256 indexed leaderboardId, address indexed player, uint256 newScore);
    event LeaderboardReset(uint256 indexed leaderboardId);

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

    function createLeaderboard(string memory name, uint256 maxEntries) public onlyRole(GAME_MANAGER_ROLE) returns (uint256) {
        require(maxEntries > 0, "LeaderboardSystem: Max entries must be greater than zero");
        uint256 leaderboardId = leaderboardCounter.current();
        Leaderboard storage newLeaderboard = leaderboards[leaderboardId];
        newLeaderboard.name = name;
        newLeaderboard.maxEntries = maxEntries;
        newLeaderboard.exists = true;
        leaderboardCounter.increment();

        emit LeaderboardCreated(leaderboardId, name, maxEntries);
        return leaderboardId;
    }

    function updateScore(uint256 leaderboardId, address player, uint256 newScore) public onlyRole(GAME_MANAGER_ROLE) whenNotPaused {
        require(leaderboards[leaderboardId].exists, "LeaderboardSystem: Leaderboard does not exist");
        Leaderboard storage leaderboard = leaderboards[leaderboardId];

        uint256 playerRank = leaderboard.playerRanks[player];
        if (playerRank > 0) {
            // Player already in leaderboard, update score
            PlayerScore storage playerScore = leaderboard.topScores[playerRank - 1];
            require(newScore > playerScore.score, "LeaderboardSystem: New score must be higher than current score");
            playerScore.score = newScore;
            playerScore.lastUpdated = block.timestamp;
        } else {
            // New player, add to leaderboard
            if (leaderboard.topScores.length < leaderboard.maxEntries) {
                leaderboard.topScores.push(PlayerScore(player, newScore, block.timestamp));
                leaderboard.playerRanks[player] = leaderboard.topScores.length;
            } else {
                // Replace lowest score if new score is higher
                if (newScore > leaderboard.topScores[leaderboard.topScores.length - 1].score) {
                    PlayerScore storage lowestScore = leaderboard.topScores[leaderboard.topScores.length - 1];
                    leaderboard.playerRanks[lowestScore.playerAddress] = 0;
                    lowestScore.playerAddress = player;
                    lowestScore.score = newScore;
                    lowestScore.lastUpdated = block.timestamp;
                    leaderboard.playerRanks[player] = leaderboard.topScores.length;
                }
            }
        }

        // Sort the leaderboard
        _sortLeaderboard(leaderboardId);

        emit ScoreUpdated(leaderboardId, player, newScore);
    }

    function getTopScores(uint256 leaderboardId, uint256 count) public view returns (PlayerScore[] memory) {
        require(leaderboards[leaderboardId].exists, "LeaderboardSystem: Leaderboard does not exist");
        Leaderboard storage leaderboard = leaderboards[leaderboardId];
        uint256 returnCount = count < leaderboard.topScores.length ? count : leaderboard.topScores.length;
        PlayerScore[] memory topScores = new PlayerScore[](returnCount);
        for (uint256 i = 0; i < returnCount; i++) {
            topScores[i] = leaderboard.topScores[i];
        }
        return topScores;
    }

    function getPlayerRank(uint256 leaderboardId, address player) public view returns (uint256) {
        require(leaderboards[leaderboardId].exists, "LeaderboardSystem: Leaderboard does not exist");
        return leaderboards[leaderboardId].playerRanks[player];
    }

    function resetLeaderboard(uint256 leaderboardId) public onlyRole(GAME_MANAGER_ROLE) {
        require(leaderboards[leaderboardId].exists, "LeaderboardSystem: Leaderboard does not exist");
        delete leaderboards[leaderboardId].topScores;
        emit LeaderboardReset(leaderboardId);
    }

    function _sortLeaderboard(uint256 leaderboardId) private {
        Leaderboard storage leaderboard = leaderboards[leaderboardId];
        uint256 n = leaderboard.topScores.length;
        for (uint256 i = 0; i < n - 1; i++) {
            for (uint256 j = 0; j < n - i - 1; j++) {
                if (leaderboard.topScores[j].score < leaderboard.topScores[j + 1].score) {
                    PlayerScore memory temp = leaderboard.topScores[j];
                    leaderboard.topScores[j] = leaderboard.topScores[j + 1];
                    leaderboard.topScores[j + 1] = temp;
                    leaderboard.playerRanks[leaderboard.topScores[j].playerAddress] = j + 1;
                    leaderboard.playerRanks[leaderboard.topScores[j + 1].playerAddress] = j + 2;
                }
            }
        }
    }

    function pause() public onlyRole(GAME_MANAGER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(GAME_MANAGER_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(UPGRADER_ROLE)
        override
    {}

    // TODO: Implement additional features such as:
    // - Time-based leaderboards (daily, weekly, monthly)
    // - Multi-dimensional leaderboards (e.g., score and time)
    // - Leaderboard archiving for historical data
    // - Gas optimization for large leaderboards (off-chain sorting with on-chain verification)
}