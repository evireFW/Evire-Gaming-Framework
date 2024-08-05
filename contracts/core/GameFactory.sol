// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./GameBase.sol";
import "./PlayerManager.sol";
import "./RandomNumberGenerator.sol";

contract GameFactory is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;

    Counters.Counter private _gameIdCounter;

    struct Game {
        uint256 gameId;
        address gameAddress;
        string gameName;
        address creator;
        uint256 creationTime;
    }

    mapping(uint256 => Game) public games;
    mapping(address => uint256[]) public userGames;

    event GameCreated(uint256 indexed gameId, address indexed gameAddress, string gameName, address indexed creator, uint256 creationTime);
    event GameJoined(uint256 indexed gameId, address indexed player);
    event GameCompleted(uint256 indexed gameId, address indexed winner);

    constructor() {}

    function createGame(string memory gameName, address playerManagerAddress, address randomGeneratorAddress) external nonReentrant {
        uint256 gameId = _gameIdCounter.current();
        address gameAddress = address(new GameBase(gameName, playerManagerAddress, randomGeneratorAddress, msg.sender));
        games[gameId] = Game({
            gameId: gameId,
            gameAddress: gameAddress,
            gameName: gameName,
            creator: msg.sender,
            creationTime: block.timestamp
        });
        userGames[msg.sender].push(gameId);

        emit GameCreated(gameId, gameAddress, gameName, msg.sender, block.timestamp);
        _gameIdCounter.increment();
    }

    function joinGame(uint256 gameId) external nonReentrant {
        require(games[gameId].gameAddress != address(0), "Game does not exist");
        GameBase game = GameBase(games[gameId].gameAddress);
        game.addPlayer(msg.sender);
        emit GameJoined(gameId, msg.sender);
    }

    function completeGame(uint256 gameId, address winner) external onlyOwner {
        require(games[gameId].gameAddress != address(0), "Game does not exist");
        GameBase game = GameBase(games[gameId].gameAddress);
        game.completeGame(winner);
        emit GameCompleted(gameId, winner);
    }

    function getGameInfo(uint256 gameId) external view returns (string memory, address, address, uint256) {
        Game memory game = games[gameId];
        return (game.gameName, game.gameAddress, game.creator, game.creationTime);
    }

    function getUserGames(address user) external view returns (uint256[] memory) {
        return userGames[user];
    }
}

contract GameBase is ERC721, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    string public gameName;
    address public playerManagerAddress;
    address public randomGeneratorAddress;
    address public creator;
    bool public isGameActive;
    mapping(address => bool) public players;
    mapping(uint256 => address) public tokenOwners;

    event PlayerAdded(address indexed player);
    event GameStarted();
    event GameEnded(address indexed winner);

    constructor(string memory _gameName, address _playerManagerAddress, address _randomGeneratorAddress, address _creator) ERC721("GameToken", "GT") {
        gameName = _gameName;
        playerManagerAddress = _playerManagerAddress;
        randomGeneratorAddress = _randomGeneratorAddress;
        creator = _creator;
        isGameActive = true;
    }

    modifier onlyPlayer() {
        require(players[msg.sender], "Not a registered player");
        _;
    }

    function addPlayer(address player) external onlyOwner {
        require(!players[player], "Player already added");
        players[player] = true;
        emit PlayerAdded(player);
    }

    function startGame() external onlyOwner {
        require(isGameActive, "Game is not active");
        emit GameStarted();
    }

    function completeGame(address winner) external onlyOwner {
        require(isGameActive, "Game is not active");
        isGameActive = false;
        mint(winner);
        emit GameEnded(winner);
    }

    function mint(address to) internal {
        uint256 tokenId = _tokenIdCounter.current();
        _safeMint(to, tokenId);
        tokenOwners[tokenId] = to;
        _tokenIdCounter.increment();
    }

    function random(uint256 seed) public view returns (uint256) {
        RandomNumberGenerator rng = RandomNumberGenerator(randomGeneratorAddress);
        return rng.getRandomNumber(seed);
    }
}
