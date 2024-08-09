// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../libraries/GameLibrary.sol";
import "../core/GameManager.sol";
import "./StateChannel.sol";
import "./PlayerState.sol";

contract GameState is AccessControl, ReentrancyGuard, Ownable {
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant GAME_MANAGER_ROLE = keccak256("GAME_MANAGER_ROLE");
    bytes32 public constant PLAYER_ROLE = keccak256("PLAYER_ROLE");

    Counters.Counter private _gameIds;

    struct Game {
        uint256 id;
        string name;
        address creator;
        bool isActive;
        uint256 startTime;
        uint256 endTime;
        EnumerableSet.AddressSet players;
        mapping(address => PlayerState) playerStates;
    }

    mapping(uint256 => Game) private games;
    mapping(address => uint256) private playerToGame;
    mapping(uint256 => bool) private activeGames;

    event GameCreated(uint256 indexed gameId, string name, address indexed creator);
    event GameStarted(uint256 indexed gameId, uint256 startTime);
    event GameEnded(uint256 indexed gameId, uint256 endTime);
    event PlayerJoined(uint256 indexed gameId, address indexed player);
    event PlayerLeft(uint256 indexed gameId, address indexed player);
    event PlayerStateUpdated(uint256 indexed gameId, address indexed player, string stateUpdate);

    constructor(address gameManager) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(GAME_MANAGER_ROLE, gameManager);
    }

    modifier onlyGameManager() {
        require(hasRole(GAME_MANAGER_ROLE, msg.sender), "GameState: caller is not a game manager");
        _;
    }

    modifier onlyActiveGame(uint256 gameId) {
        require(games[gameId].isActive, "GameState: game is not active");
        _;
    }

    modifier onlyPlayerInGame(uint256 gameId) {
        require(games[gameId].players.contains(msg.sender), "GameState: caller is not a player in this game");
        _;
    }

    function createGame(string memory name) external onlyGameManager nonReentrant returns (uint256) {
        _gameIds.increment();
        uint256 newGameId = _gameIds.current();

        Game storage newGame = games[newGameId];
        newGame.id = newGameId;
        newGame.name = name;
        newGame.creator = msg.sender;
        newGame.isActive = false;

        activeGames[newGameId] = true;

        emit GameCreated(newGameId, name, msg.sender);

        return newGameId;
    }

    function startGame(uint256 gameId) external onlyGameManager onlyActiveGame(gameId) nonReentrant {
        Game storage game = games[gameId];
        require(!game.isActive, "GameState: game is already active");

        game.isActive = true;
        game.startTime = block.timestamp;

        emit GameStarted(gameId, block.timestamp);
    }

    function endGame(uint256 gameId) external onlyGameManager onlyActiveGame(gameId) nonReentrant {
        Game storage game = games[gameId];
        require(game.isActive, "GameState: game is not active");

        game.isActive = false;
        game.endTime = block.timestamp;

        activeGames[gameId] = false;

        emit GameEnded(gameId, block.timestamp);
    }

    function joinGame(uint256 gameId) external onlyActiveGame(gameId) nonReentrant {
        Game storage game = games[gameId];
        require(!game.players.contains(msg.sender), "GameState: player is already in the game");

        game.players.add(msg.sender);
        playerToGame[msg.sender] = gameId;
        game.playerStates[msg.sender] = new PlayerState();

        emit PlayerJoined(gameId, msg.sender);
    }

    function leaveGame(uint256 gameId) external onlyActiveGame(gameId) onlyPlayerInGame(gameId) nonReentrant {
        Game storage game = games[gameId];
        require(game.players.contains(msg.sender), "GameState: player is not in the game");

        game.players.remove(msg.sender);
        delete playerToGame[msg.sender];
        delete game.playerStates[msg.sender];

        emit PlayerLeft(gameId, msg.sender);
    }

    function updatePlayerState(uint256 gameId, string memory stateUpdate) external onlyActiveGame(gameId) onlyPlayerInGame(gameId) nonReentrant {
        Game storage game = games[gameId];
        require(game.players.contains(msg.sender), "GameState: player is not in the game");

        PlayerState playerState = game.playerStates[msg.sender];
        playerState.updateState(stateUpdate);

        emit PlayerStateUpdated(gameId, msg.sender, stateUpdate);
    }

    function getGame(uint256 gameId) external view returns (Game memory) {
        return games[gameId];
    }

    function getPlayerState(uint256 gameId, address player) external view returns (PlayerState) {
        return games[gameId].playerStates[player];
    }

    function getPlayers(uint256 gameId) external view returns (address[] memory) {
        Game storage game = games[gameId];
        return game.players.values();
    }

    function isPlayerInGame(uint256 gameId, address player) external view returns (bool) {
        return games[gameId].players.contains(player);
    }

    function isGameActive(uint256 gameId) external view returns (bool) {
        return games[gameId].isActive;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
