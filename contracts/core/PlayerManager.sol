// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract PlayerManager is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    struct Player {
        uint256 id;
        string username;
        address wallet;
        uint256 score;
        bool isActive;
        uint256 createdAt;
        uint256 updatedAt;
    }

    Counters.Counter private _playerIdCounter;
    mapping(uint256 => Player) private _players;
    mapping(address => uint256) private _playerIdsByWallet;
    mapping(string => uint256) private _playerIdsByUsername;
    address[] private _wallets;

    event PlayerCreated(uint256 indexed playerId, string username, address indexed wallet);
    event PlayerUpdated(uint256 indexed playerId, string username, address indexed wallet, uint256 score);
    event PlayerDeactivated(uint256 indexed playerId, string username, address indexed wallet);

    modifier onlyActivePlayer(uint256 playerId) {
        require(_players[playerId].isActive, "PlayerManager: player is not active");
        _;
    }

    modifier onlyValidUsername(string memory username) {
        require(bytes(username).length > 0, "PlayerManager: username cannot be empty");
        require(_playerIdsByUsername[username] == 0, "PlayerManager: username already taken");
        _;
    }

    function createPlayer(string memory username, address wallet) external onlyOwner onlyValidUsername(username) nonReentrant {
        require(wallet != address(0), "PlayerManager: wallet address cannot be zero address");

        _playerIdCounter.increment();
        uint256 playerId = _playerIdCounter.current();

        _players[playerId] = Player({
            id: playerId,
            username: username,
            wallet: wallet,
            score: 0,
            isActive: true,
            createdAt: block.timestamp,
            updatedAt: block.timestamp
        });

        _playerIdsByWallet[wallet] = playerId;
        _playerIdsByUsername[username] = playerId;
        _wallets.push(wallet);

        emit PlayerCreated(playerId, username, wallet);
    }

    function updatePlayer(uint256 playerId, string memory username, uint256 score) external onlyOwner onlyActivePlayer(playerId) nonReentrant {
        Player storage player = _players[playerId];
        require(bytes(username).length > 0, "PlayerManager: username cannot be empty");

        if (keccak256(bytes(player.username)) != keccak256(bytes(username))) {
            require(_playerIdsByUsername[username] == 0, "PlayerManager: username already taken");
            _playerIdsByUsername[player.username] = 0;
            player.username = username;
            _playerIdsByUsername[username] = playerId;
        }

        player.score = score;
        player.updatedAt = block.timestamp;

        emit PlayerUpdated(playerId, username, player.wallet, score);
    }

    function deactivatePlayer(uint256 playerId) external onlyOwner onlyActivePlayer(playerId) nonReentrant {
        Player storage player = _players[playerId];
        player.isActive = false;
        player.updatedAt = block.timestamp;

        emit PlayerDeactivated(playerId, player.username, player.wallet);
    }

    function getPlayerById(uint256 playerId) external view returns (Player memory) {
        return _players[playerId];
    }

    function getPlayerByWallet(address wallet) external view returns (Player memory) {
        uint256 playerId = _playerIdsByWallet[wallet];
        return _players[playerId];
    }

    function getPlayerByUsername(string memory username) external view returns (Player memory) {
        uint256 playerId = _playerIdsByUsername[username];
        return _players[playerId];
    }

    function getAllPlayers() external view returns (Player[] memory) {
        Player[] memory players = new Player[](_wallets.length);
        for (uint256 i = 0; i < _wallets.length; i++) {
            uint256 playerId = _playerIdsByWallet[_wallets[i]];
            players[i] = _players[playerId];
        }
        return players;
    }

    function getActivePlayers() external view returns (Player[] memory) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < _wallets.length; i++) {
            if (_players[_playerIdsByWallet[_wallets[i]]].isActive) {
                activeCount++;
            }
        }

        Player[] memory activePlayers = new Player[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < _wallets.length; i++) {
            if (_players[_playerIdsByWallet[_wallets[i]]].isActive) {
                activePlayers[index] = _players[_playerIdsByWallet[_wallets[i]]];
                index++;
            }
        }
        return activePlayers;
    }

    function getInactivePlayers() external view returns (Player[] memory) {
        uint256 inactiveCount = 0;
        for (uint256 i = 0; i < _wallets.length; i++) {
            if (!_players[_playerIdsByWallet[_wallets[i]]].isActive) {
                inactiveCount++;
            }
        }

        Player[] memory inactivePlayers = new Player[](inactiveCount);
        uint256 index = 0;
        for (uint256 i = 0; i < _wallets.length; i++) {
            if (!_players[_playerIdsByWallet[_wallets[i]]].isActive) {
                inactivePlayers[index] = _players[_playerIdsByWallet[_wallets[i]]];
                index++;
            }
        }
        return inactivePlayers;
    }
}
