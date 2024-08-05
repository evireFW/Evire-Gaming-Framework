// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title GameBase
 * @dev Base contract for managing games on the Evire blockchain. Provides fundamental structures and functions for game management.
 */
contract GameBase {
    // Define the owner of the contract
    address public owner;

    // Struct to represent a player
    struct Player {
        address playerAddress;
        uint256 score;
        uint256 level;
        bool active;
    }

    // Struct to represent a game
    struct Game {
        uint256 gameId;
        string name;
        address[] players;
        mapping(address => Player) playerInfo;
        uint256 startTime;
        uint256 endTime;
        bool active;
    }

    // Mapping from game ID to Game struct
    mapping(uint256 => Game) public games;

    // Counter for generating unique game IDs
    uint256 private gameIdCounter;

    // Event emitted when a new game is created
    event GameCreated(uint256 indexed gameId, string name, uint256 startTime, address creator);

    // Event emitted when a player joins a game
    event PlayerJoined(uint256 indexed gameId, address indexed player);

    // Event emitted when a game ends
    event GameEnded(uint256 indexed gameId, uint256 endTime);

    /**
     * @dev Modifier to restrict access to the owner of the contract.
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    /**
     * @dev Modifier to check if the game exists.
     */
    modifier gameExists(uint256 _gameId) {
        require(games[_gameId].active, "Game does not exist");
        _;
    }

    /**
     * @dev Constructor to set the owner of the contract.
     */
    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Function to create a new game.
     * @param _name The name of the game.
     */
    function createGame(string memory _name) public onlyOwner {
        gameIdCounter++;
        uint256 newGameId = gameIdCounter;

        Game storage newGame = games[newGameId];
        newGame.gameId = newGameId;
        newGame.name = _name;
        newGame.startTime = block.timestamp;
        newGame.active = true;

        emit GameCreated(newGameId, _name, block.timestamp, msg.sender);
    }

    /**
     * @dev Function to add a player to a game.
     * @param _gameId The ID of the game.
     * @param _player The address of the player.
     */
    function addPlayer(uint256 _gameId, address _player) public gameExists(_gameId) onlyOwner {
        Game storage game = games[_gameId];
        require(!game.playerInfo[_player].active, "Player already in game");

        game.players.push(_player);
        game.playerInfo[_player] = Player({
            playerAddress: _player,
            score: 0,
            level: 1,
            active: true
        });

        emit PlayerJoined(_gameId, _player);
    }

    /**
     * @dev Function to update player score.
     * @param _gameId The ID of the game.
     * @param _player The address of the player.
     * @param _score The new score of the player.
     */
    function updatePlayerScore(uint256 _gameId, address _player, uint256 _score) public gameExists(_gameId) onlyOwner {
        Game storage game = games[_gameId];
        require(game.playerInfo[_player].active, "Player not in game");

        game.playerInfo[_player].score = _score;
    }

    /**
     * @dev Function to end a game.
     * @param _gameId The ID of the game.
     */
    function endGame(uint256 _gameId) public gameExists(_gameId) onlyOwner {
        Game storage game = games[_gameId];
        game.endTime = block.timestamp;
        game.active = false;

        emit GameEnded(_gameId, block.timestamp);
    }

    /**
     * @dev Function to get player information in a game.
     * @param _gameId The ID of the game.
     * @param _player The address of the player.
     * @return Player struct containing player details.
     */
    function getPlayerInfo(uint256 _gameId, address _player) public view gameExists(_gameId) returns (Player memory) {
        Game storage game = games[_gameId];
        require(game.playerInfo[_player].active, "Player not in game");

        return game.playerInfo[_player];
    }

    /**
     * @dev Function to get the list of players in a game.
     * @param _gameId The ID of the game.
     * @return List of player addresses.
     */
    function getPlayers(uint256 _gameId) public view gameExists(_gameId) returns (address[] memory) {
        return games[_gameId].players;
    }
}
