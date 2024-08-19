# Evire Gaming Framework API Documentation

## Table of Contents
1. [Introduction](#introduction)
2. [Smart Contracts](#smart-contracts)
3. [Backend Services](#backend-services)
4. [Frontend Integration](#frontend-integration)
5. [WebSocket API](#websocket-api)
6. [RESTful API](#restful-api)
7. [Error Handling](#error-handling)
8. [Rate Limiting](#rate-limiting)
9. [Authentication and Authorization](#authentication-and-authorization)
10. [Versioning](#versioning)

## Introduction

The Evire Gaming Framework API provides a comprehensive suite of tools and services for building blockchain-based games on the Evire platform. This document outlines the available endpoints, methods, and data structures for interacting with the framework.

## Smart Contracts

### Asset Management

#### AssetFactory

- `createAsset(string memory name, uint256 assetType) public returns (uint256)`
  Creates a new asset and returns its unique identifier.

- `getAsset(uint256 assetId) public view returns (string memory, uint256)`
  Retrieves asset details by ID.

#### NFTAsset

- `mint(address to, uint256 tokenId) public`
  Mints a new NFT to the specified address.

- `burn(uint256 tokenId) public`
  Burns (destroys) the specified NFT.

### Game Management

#### GameFactory

- `createGame(string memory name, uint256 gameType) public returns (address)`
  Creates a new game instance and returns its address.

#### GameManager

- `startGame(address gameAddress) public`
  Starts a game instance.

- `endGame(address gameAddress) public`
  Ends a game instance and distributes rewards.

### Economy

#### Marketplace

- `listItem(uint256 assetId, uint256 price) public`
  Lists an item for sale on the marketplace.

- `buyItem(uint256 listingId) public payable`
  Purchases a listed item.

#### Auction

- `createAuction(uint256 assetId, uint256 startingPrice, uint256 duration) public`
  Creates a new auction for an asset.

- `placeBid(uint256 auctionId) public payable`
  Places a bid on an ongoing auction.

## Backend Services

### Matchmaking Service

- `POST /api/matchmaking/queue`
  Adds a player to the matchmaking queue.

- `GET /api/matchmaking/status/{playerId}`
  Retrieves the current matchmaking status for a player.

### Leaderboard Service

- `GET /api/leaderboard/global`
  Retrieves the global leaderboard.

- `GET /api/leaderboard/game/{gameId}`
  Retrieves the leaderboard for a specific game.

## Frontend Integration

### Web3 Integration

The frontend can interact with smart contracts using the Web3.js library. Example:

```javascript
const web3 = new Web3(window.ethereum);
const gameFactoryContract = new web3.eth.Contract(GameFactoryABI, GameFactoryAddress);

async function createGame(name, gameType) {
  const accounts = await web3.eth.getAccounts();
  await gameFactoryContract.methods.createGame(name, gameType).send({ from: accounts[0] });
}
```

## WebSocket API

The WebSocket API provides real-time updates for game events.

- Connection URL: `wss://api.evire.io/ws`

### Events

- `gameStart`: Emitted when a game starts.
- `gameEnd`: Emitted when a game ends.
- `assetTransfer`: Emitted when an asset is transferred.

## RESTful API

The RESTful API provides access to off-chain data and services.

Base URL: `https://api.evire.io/v1`

### Endpoints

- `GET /players/{playerId}`
  Retrieves player information.

- `GET /games/{gameId}/state`
  Retrieves the current state of a game.

- `POST /transactions/initiate`
  Initiates a new blockchain transaction.

## Error Handling

All API responses follow a standard error format:

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message"
  }
}
```

Common error codes:
- `400`: Bad Request
- `401`: Unauthorized
- `403`: Forbidden
- `404`: Not Found
- `500`: Internal Server Error

## Rate Limiting

API requests are rate-limited to ensure fair usage. The current limits are:

- 100 requests per minute for authenticated users
- 20 requests per minute for unauthenticated users

Rate limit information is included in the response headers:
- `X-RateLimit-Limit`: The number of allowed requests in the current period
- `X-RateLimit-Remaining`: The number of remaining requests in the current period
- `X-RateLimit-Reset`: The time at which the current rate limit window resets

## Authentication and Authorization

API authentication is handled using JSON Web Tokens (JWT).

To authenticate, send a POST request to `/auth/login` with your credentials. The response will include a JWT token.

Include the token in the `Authorization` header for subsequent requests:

```
Authorization: Bearer <your_jwt_token>
```

## Versioning

The API uses semantic versioning. The current version is v1. When making requests, include the version in the URL:

```
https://api.evire.io/v1/endpoint
```

Major version changes may include breaking changes and will be communicated well in advance.