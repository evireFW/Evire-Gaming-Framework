// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title GameLibrary
 * @dev This library provides a set of functions to facilitate game development on the blockchain.
 * It includes utilities for managing game states, generating random numbers, calculating scores,
 * managing in-game assets, and more.
 */
library GameLibrary {
    using SafeMath for uint256;

    struct Player {
        address playerAddress;
        uint256 score;
        uint256 level;
        uint256 experience;
        mapping(uint256 => uint256) inventory; // itemId => quantity
    }

    struct GameState {
        uint256 gameId;
        mapping(address => Player) players;
        uint256[] activePlayerAddresses;
        uint256 totalPlayers;
        uint256 startTime;
        uint256 endTime;
    }

    event PlayerJoined(address indexed player, uint256 gameId);
    event PlayerLeft(address indexed player, uint256 gameId);
    event PlayerScored(address indexed player, uint256 gameId, uint256 score);
    event GameStarted(uint256 gameId, uint256 startTime);
    event GameEnded(uint256 gameId, uint256 endTime);

    /**
     * @dev Initializes a new game state.
     * @param self The game state to initialize.
     * @param gameId The unique identifier for the game.
     */
    function initializeGameState(GameState storage self, uint256 gameId) public {
        self.gameId = gameId;
        self.totalPlayers = 0;
        self.startTime = block.timestamp;
        self.endTime = 0;
        emit GameStarted(gameId, block.timestamp);
    }

    /**
     * @dev Adds a player to the game state.
     * @param self The game state to modify.
     * @param player The address of the player to add.
     */
    function addPlayer(GameState storage self, address player) public {
        require(self.players[player].playerAddress == address(0), "Player already exists");
        self.players[player] = Player(player, 0, 1, 0);
        self.activePlayerAddresses.push(player);
        self.totalPlayers = self.totalPlayers.add(1);
        emit PlayerJoined(player, self.gameId);
    }

    /**
     * @dev Removes a player from the game state.
     * @param self The game state to modify.
     * @param player The address of the player to remove.
     */
    function removePlayer(GameState storage self, address player) public {
        require(self.players[player].playerAddress != address(0), "Player does not exist");
        delete self.players[player];
        for (uint256 i = 0; i < self.activePlayerAddresses.length; i++) {
            if (self.activePlayerAddresses[i] == player) {
                self.activePlayerAddresses[i] = self.activePlayerAddresses[self.activePlayerAddresses.length - 1];
                self.activePlayerAddresses.pop();
                break;
            }
        }
        self.totalPlayers = self.totalPlayers.sub(1);
        emit PlayerLeft(player, self.gameId);
    }

    /**
     * @dev Updates the score for a player.
     * @param self The game state to modify.
     * @param player The address of the player to update.
     * @param score The score to add to the player's total.
     */
    function updatePlayerScore(GameState storage self, address player, uint256 score) public {
        require(self.players[player].playerAddress != address(0), "Player does not exist");
        self.players[player].score = self.players[player].score.add(score);
        emit PlayerScored(player, self.gameId, score);
    }

    /**
     * @dev Ends the game and records the end time.
     * @param self The game state to modify.
     */
    function endGame(GameState storage self) public {
        require(self.endTime == 0, "Game already ended");
        self.endTime = block.timestamp;
        emit GameEnded(self.gameId, block.timestamp);
    }

    /**
     * @dev Generates a random number between min and max.
     * @param min The minimum value (inclusive).
     * @param max The maximum value (inclusive).
     * @return A random number between min and max.
     */
    function random(uint256 min, uint256 max) public view returns (uint256) {
        require(max > min, "max must be greater than min");
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty))) % (max - min + 1) + min;
    }

    /**
     * @dev Adds an item to the player's inventory.
     * @param self The game state to modify.
     * @param player The address of the player to update.
     * @param itemId The ID of the item to add.
     * @param quantity The quantity of the item to add.
     */
    function addItemToInventory(GameState storage self, address player, uint256 itemId, uint256 quantity) public {
        require(self.players[player].playerAddress != address(0), "Player does not exist");
        self.players[player].inventory[itemId] = self.players[player].inventory[itemId].add(quantity);
    }

    /**
     * @dev Removes an item from the player's inventory.
     * @param self The game state to modify.
     * @param player The address of the player to update.
     * @param itemId The ID of the item to remove.
     * @param quantity The quantity of the item to remove.
     */
    function removeItemFromInventory(GameState storage self, address player, uint256 itemId, uint256 quantity) public {
        require(self.players[player].playerAddress != address(0), "Player does not exist");
        require(self.players[player].inventory[itemId] >= quantity, "Insufficient quantity");
        self.players[player].inventory[itemId] = self.players[player].inventory[itemId].sub(quantity);
    }

    /**
     * @dev Calculates the player's level based on their experience.
     * @param self The game state to modify.
     * @param player The address of the player to update.
     * @param experience The experience points to add.
     */
    function calculateLevel(GameState storage self, address player, uint256 experience) public {
        require(self.players[player].playerAddress != address(0), "Player does not exist");
        self.players[player].experience = self.players[player].experience.add(experience);
        self.players[player].level = self.players[player].experience.div(1000);
    }

    /**
     * @dev Retrieves the player's current score.
     * @param self The game state to query.
     * @param player The address of the player to query.
     * @return The player's current score.
     */
    function getPlayerScore(GameState storage self, address player) public view returns (uint256) {
        require(self.players[player].playerAddress != address(0), "Player does not exist");
        return self.players[player].score;
    }

    /**
     * @dev Retrieves the player's current level.
     * @param self The game state to query.
     * @param player The address of the player to query.
     * @return The player's current level.
     */
    function getPlayerLevel(GameState storage self, address player) public view returns (uint256) {
        require(self.players[player].playerAddress != address(0), "Player does not exist");
        return self.players[player].level;
    }

    /**
     * @dev Retrieves the quantity of an item in the player's inventory.
     * @param self The game state to query.
     * @param player The address of the player to query.
     * @param itemId The ID of the item to query.
     * @return The quantity of the item in the player's inventory.
     */
    function getInventoryItemQuantity(GameState storage self, address player, uint256 itemId) public view returns (uint256) {
        require(self.players[player].playerAddress != address(0), "Player does not exist");
        return self.players[player].inventory[itemId];
    }
}
