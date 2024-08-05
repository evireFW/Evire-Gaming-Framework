// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../libraries/RandomNumberGenerator.sol";
import "../libraries/GameLibrary.sol";
import "./PlayerManager.sol";

contract GameManager is Ownable {
    using SafeMath for uint256;

    enum GameState { Created, Started, Ended }
    
    struct Game {
        uint256 id;
        address creator;
        GameState state;
        uint256 entryFee;
        uint256 prizePool;
        address[] players;
        uint256 startTime;
        uint256 endTime;
    }

    struct PlayerStats {
        uint256 wins;
        uint256 losses;
        uint256 gamesPlayed;
        uint256 totalEarnings;
    }

    mapping(uint256 => Game) public games;
    mapping(address => PlayerStats) public playerStats;
    uint256 public nextGameId;

    address public playerManager;
    address public rewardToken;
    uint256 public minEntryFee;
    uint256 public maxPlayers;
    uint256 public gameDuration;

    event GameCreated(uint256 indexed gameId, address indexed creator, uint256 entryFee);
    event GameStarted(uint256 indexed gameId, uint256 startTime);
    event GameEnded(uint256 indexed gameId, uint256 endTime, address winner, uint256 prize);

    modifier onlyPlayer() {
        require(PlayerManager(playerManager).isPlayer(msg.sender), "Not a registered player");
        _;
    }

    constructor(address _playerManager, address _rewardToken, uint256 _minEntryFee, uint256 _maxPlayers, uint256 _gameDuration) {
        playerManager = _playerManager;
        rewardToken = _rewardToken;
        minEntryFee = _minEntryFee;
        maxPlayers = _maxPlayers;
        gameDuration = _gameDuration;
    }

    function createGame(uint256 entryFee) external onlyPlayer returns (uint256) {
        require(entryFee >= minEntryFee, "Entry fee too low");

        uint256 gameId = nextGameId++;
        Game storage game = games[gameId];
        game.id = gameId;
        game.creator = msg.sender;
        game.state = GameState.Created;
        game.entryFee = entryFee;

        emit GameCreated(gameId, msg.sender, entryFee);
        return gameId;
    }

    function joinGame(uint256 gameId) external onlyPlayer {
        Game storage game = games[gameId];
        require(game.state == GameState.Created, "Game not open for joining");
        require(game.players.length < maxPlayers, "Game is full");

        IERC20(rewardToken).transferFrom(msg.sender, address(this), game.entryFee);
        game.players.push(msg.sender);
        game.prizePool = game.prizePool.add(game.entryFee);

        if (game.players.length == maxPlayers) {
            startGame(gameId);
        }
    }

    function startGame(uint256 gameId) internal {
        Game storage game = games[gameId];
        require(game.state == GameState.Created, "Game already started or ended");

        game.state = GameState.Started;
        game.startTime = block.timestamp;
        
        emit GameStarted(gameId, block.timestamp);
    }

    function endGame(uint256 gameId) external onlyOwner {
        Game storage game = games[gameId];
        require(game.state == GameState.Started, "Game not started");
        require(block.timestamp >= game.startTime.add(gameDuration), "Game duration not reached");

        address winner = determineWinner(gameId);
        game.state = GameState.Ended;
        game.endTime = block.timestamp;
        
        IERC20(rewardToken).transfer(winner, game.prizePool);

        updatePlayerStats(gameId, winner);

        emit GameEnded(gameId, block.timestamp, winner, game.prizePool);
    }

    function determineWinner(uint256 gameId) internal view returns (address) {
        Game storage game = games[gameId];
        uint256 randomIndex = RandomNumberGenerator.random(game.players.length);
        return game.players[randomIndex];
    }

    function updatePlayerStats(uint256 gameId, address winner) internal {
        Game storage game = games[gameId];
        for (uint256 i = 0; i < game.players.length; i++) {
            address player = game.players[i];
            PlayerStats storage stats = playerStats[player];
            stats.gamesPlayed = stats.gamesPlayed.add(1);
            if (player == winner) {
                stats.wins = stats.wins.add(1);
                stats.totalEarnings = stats.totalEarnings.add(game.prizePool);
            } else {
                stats.losses = stats.losses.add(1);
            }
        }
    }

    function setMinEntryFee(uint256 _minEntryFee) external onlyOwner {
        minEntryFee = _minEntryFee;
    }

    function setMaxPlayers(uint256 _maxPlayers) external onlyOwner {
        maxPlayers = _maxPlayers;
    }

    function setGameDuration(uint256 _gameDuration) external onlyOwner {
        gameDuration = _gameDuration;
    }

    function withdrawFunds(uint256 amount) external onlyOwner {
        IERC20(rewardToken).transfer(msg.sender, amount);
    }

    function getGamePlayers(uint256 gameId) external view returns (address[] memory) {
        return games[gameId].players;
    }

    function getPlayerStats(address player) external view returns (uint256 wins, uint256 losses, uint256 gamesPlayed, uint256 totalEarnings) {
        PlayerStats storage stats = playerStats[player];
        return (stats.wins, stats.losses, stats.gamesPlayed, stats.totalEarnings);
    }
}
