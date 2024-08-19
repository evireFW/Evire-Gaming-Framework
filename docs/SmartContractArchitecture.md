# Evire Gaming Framework: Smart Contract Architecture

## Overview

The Evire Gaming Framework utilizes a modular smart contract architecture to provide a flexible, secure, and scalable foundation for blockchain-based games. This document outlines the key components and their interactions within the framework.

## Core Components

### 1. GameBase.sol

The foundational contract for all games built on the Evire Gaming Framework.

```solidity
pragma solidity ^0.8.0;

import "./GameState.sol";
import "./PlayerManager.sol";

abstract contract GameBase {
    GameState public gameState;
    PlayerManager public playerManager;

    constructor(address _playerManager) {
        playerManager = PlayerManager(_playerManager);
        gameState = new GameState();
    }

    function startGame() virtual public;
    function endGame() virtual public;
    function updateGameState() virtual public;
}
```

### 2. GameFactory.sol

Responsible for creating and deploying new game instances.

```solidity
pragma solidity ^0.8.0;

import "./GameBase.sol";

contract GameFactory {
    event GameCreated(address gameAddress, uint256 gameId);

    function createGame(string memory gameType) public returns (address) {
        // Implementation depends on the specific game type
        // Example:
        // GameBase newGame = new SpecificGame(msg.sender);
        // emit GameCreated(address(newGame), newGame.gameId());
        // return address(newGame);
    }
}
```

### 3. GameManager.sol

Manages the lifecycle of games and coordinates between different game components.

```solidity
pragma solidity ^0.8.0;

import "./GameBase.sol";
import "./GameFactory.sol";

contract GameManager {
    GameFactory public gameFactory;
    mapping(uint256 => address) public games;

    constructor(address _gameFactory) {
        gameFactory = GameFactory(_gameFactory);
    }

    function createGame(string memory gameType) public {
        address newGame = gameFactory.createGame(gameType);
        uint256 gameId = GameBase(newGame).gameId();
        games[gameId] = newGame;
    }

    function getGameAddress(uint256 gameId) public view returns (address) {
        return games[gameId];
    }
}
```

## Asset Management

### 1. AssetFactory.sol

Creates different types of in-game assets.

```solidity
pragma solidity ^0.8.0;

import "./NFTAsset.sol";
import "./FungibleToken.sol";

contract AssetFactory {
    function createNFT(string memory uri) public returns (address) {
        NFTAsset newNFT = new NFTAsset(uri);
        return address(newNFT);
    }

    function createFungibleToken(string memory name, string memory symbol) public returns (address) {
        FungibleToken newToken = new FungibleToken(name, symbol);
        return address(newToken);
    }
}
```

### 2. AssetManager.sol

Manages the lifecycle and ownership of in-game assets.

```solidity
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AssetManager {
    mapping(address => mapping(address => uint256[])) private nftOwnership;
    mapping(address => mapping(address => uint256)) private tokenBalances;

    function depositNFT(address nftContract, uint256 tokenId) public {
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
        nftOwnership[msg.sender][nftContract].push(tokenId);
    }

    function withdrawNFT(address nftContract, uint256 tokenId) public {
        require(ownsNFT(msg.sender, nftContract, tokenId), "You don't own this NFT");
        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);
        removeNFTFromOwnership(msg.sender, nftContract, tokenId);
    }

    function depositTokens(address tokenContract, uint256 amount) public {
        IERC20(tokenContract).transferFrom(msg.sender, address(this), amount);
        tokenBalances[msg.sender][tokenContract] += amount;
    }

    function withdrawTokens(address tokenContract, uint256 amount) public {
        require(tokenBalances[msg.sender][tokenContract] >= amount, "Insufficient balance");
        IERC20(tokenContract).transfer(msg.sender, amount);
        tokenBalances[msg.sender][tokenContract] -= amount;
    }

    function ownsNFT(address owner, address nftContract, uint256 tokenId) public view returns (bool) {
        uint256[] memory ownedTokens = nftOwnership[owner][nftContract];
        for (uint i = 0; i < ownedTokens.length; i++) {
            if (ownedTokens[i] == tokenId) {
                return true;
            }
        }
        return false;
    }

    function removeNFTFromOwnership(address owner, address nftContract, uint256 tokenId) private {
        uint256[] storage ownedTokens = nftOwnership[owner][nftContract];
        for (uint i = 0; i < ownedTokens.length; i++) {
            if (ownedTokens[i] == tokenId) {
                ownedTokens[i] = ownedTokens[ownedTokens.length - 1];
                ownedTokens.pop();
                break;
            }
        }
    }
}
```

## Economy

### 1. Marketplace.sol

Facilitates the buying, selling, and trading of in-game assets.

```solidity
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./AssetManager.sol";

contract Marketplace {
    struct Listing {
        address seller;
        address assetContract;
        uint256 tokenId;
        uint256 price;
        bool isActive;
    }

    AssetManager public assetManager;
    mapping(uint256 => Listing) public listings;
    uint256 public nextListingId;

    constructor(address _assetManager) {
        assetManager = AssetManager(_assetManager);
    }

    function createListing(address assetContract, uint256 tokenId, uint256 price) public {
        require(assetManager.ownsNFT(msg.sender, assetContract, tokenId), "You don't own this asset");
        listings[nextListingId] = Listing(msg.sender, assetContract, tokenId, price, true);
        nextListingId++;
    }

    function buyListing(uint256 listingId) public payable {
        Listing storage listing = listings[listingId];
        require(listing.isActive, "Listing is not active");
        require(msg.value >= listing.price, "Insufficient payment");

        IERC721(listing.assetContract).transferFrom(address(assetManager), msg.sender, listing.tokenId);
        payable(listing.seller).transfer(listing.price);

        if (msg.value > listing.price) {
            payable(msg.sender).transfer(msg.value - listing.price);
        }

        listing.isActive = false;
    }

    function cancelListing(uint256 listingId) public {
        Listing storage listing = listings[listingId];
        require(msg.sender == listing.seller, "Only the seller can cancel the listing");
        listing.isActive = false;
    }
}
```

### 2. Auction.sol

Implements an auction system for high-value or rare in-game assets.

```solidity
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./AssetManager.sol";

contract Auction {
    struct AuctionInfo {
        address seller;
        address assetContract;
        uint256 tokenId;
        uint256 startingPrice;
        uint256 endTime;
        address highestBidder;
        uint256 highestBid;
        bool ended;
    }

    AssetManager public assetManager;
    mapping(uint256 => AuctionInfo) public auctions;
    uint256 public nextAuctionId;

    constructor(address _assetManager) {
        assetManager = AssetManager(_assetManager);
    }

    function createAuction(address assetContract, uint256 tokenId, uint256 startingPrice, uint256 duration) public {
        require(assetManager.ownsNFT(msg.sender, assetContract, tokenId), "You don't own this asset");
        uint256 endTime = block.timestamp + duration;
        auctions[nextAuctionId] = AuctionInfo(msg.sender, assetContract, tokenId, startingPrice, endTime, address(0), 0, false);
        nextAuctionId++;
    }

    function placeBid(uint256 auctionId) public payable {
        AuctionInfo storage auction = auctions[auctionId];
        require(block.timestamp < auction.endTime, "Auction has ended");
        require(msg.value > auction.highestBid, "Bid must be higher than current highest bid");

        if (auction.highestBidder != address(0)) {
            payable(auction.highestBidder).transfer(auction.highestBid);
        }

        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;
    }

    function endAuction(uint256 auctionId) public {
        AuctionInfo storage auction = auctions[auctionId];
        require(block.timestamp >= auction.endTime, "Auction has not ended yet");
        require(!auction.ended, "Auction has already been ended");

        auction.ended = true;
        if (auction.highestBidder != address(0)) {
            IERC721(auction.assetContract).transferFrom(address(assetManager), auction.highestBidder, auction.tokenId);
            payable(auction.seller).transfer(auction.highestBid);
        } else {
            IERC721(auction.assetContract).transferFrom(address(assetManager), auction.seller, auction.tokenId);
        }
    }
}
```

## Compliance

### 1. ComplianceManager.sol

Manages compliance checks and restrictions for game activities.

```solidity
pragma solidity ^0.8.0;

import "./KYC.sol";
import "./AMLChecks.sol";

contract ComplianceManager {
    KYC public kyc;
    AMLChecks public amlChecks;

    constructor(address _kyc, address _amlChecks) {
        kyc = KYC(_kyc);
        amlChecks = AMLChecks(_amlChecks);
    }

    function checkCompliance(address user, uint256 amount) public view returns (bool) {
        return kyc.isVerified(user) && amlChecks.checkTransaction(user, amount);
    }

    function updateKYCStatus(address user, bool status) public {
        // TODO: Add access control
        kyc.updateStatus(user, status);
    }

    function flagForAMLReview(address user) public {
        // TODO: Add access control
        amlChecks.flagAddress(user);
    }
}
```

## Oracles

### 1. RandomOracle.sol

Provides verifiable random numbers for game mechanics.

```solidity
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

contract RandomOracle is VRFConsumerBase {
    bytes32 internal keyHash;
    uint256 internal fee;
    
    mapping(bytes32 => uint256) public randomResults;

    constructor(address _vrfCoordinator, address _link, bytes32 _keyHash, uint256 _fee)
        VRFConsumerBase(_vrfCoordinator, _link)
    {
        keyHash = _keyHash;
        fee = _fee;
    }

    function getRandomNumber() public returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK");
        return requestRandomness(keyHash, fee);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        randomResults[requestId] = randomness;
    }

    function getRandomResult(bytes32 requestId) public view returns (uint256) {
        return randomResults[requestId];
    }
}
```
