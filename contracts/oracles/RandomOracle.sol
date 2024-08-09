// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

contract RandomOracle is VRFConsumerBase, Ownable, ReentrancyGuard {
    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 public lastRandomResult;
    uint256 private randomRequestCount;

    mapping(bytes32 => address) private requestToSender;
    mapping(bytes32 => bool) private requestFulfilled;

    event RandomnessRequested(bytes32 indexed requestId, address indexed requester);
    event RandomnessFulfilled(bytes32 indexed requestId, uint256 indexed randomness);

    constructor(
        address vrfCoordinator,
        address linkToken,
        bytes32 _keyHash,
        uint256 _fee
    ) VRFConsumerBase(vrfCoordinator, linkToken) {
        keyHash = _keyHash;
        fee = _fee;
    }

    function requestRandomNumber() external nonReentrant returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "RandomOracle: Not enough LINK to pay fee");
        requestId = requestRandomness(keyHash, fee);
        requestToSender[requestId] = msg.sender;
        randomRequestCount++;
        emit RandomnessRequested(requestId, msg.sender);
        return requestId;
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        require(!requestFulfilled[requestId], "RandomOracle: Randomness already fulfilled for this request");
        lastRandomResult = randomness;
        requestFulfilled[requestId] = true;
        emit RandomnessFulfilled(requestId, randomness);
    }

    function getRandomNumber(uint256 maxValue) external view returns (uint256) {
        require(lastRandomResult > 0, "RandomOracle: Randomness not available");
        return (lastRandomResult % maxValue) + 1;
    }

    function isRequestFulfilled(bytes32 requestId) external view returns (bool) {
        return requestFulfilled[requestId];
    }

    function getRandomRequestCount() external view returns (uint256) {
        return randomRequestCount;
    }

    function withdrawLinkTokens() external onlyOwner {
        uint256 balance = LINK.balanceOf(address(this));
        require(balance > 0, "RandomOracle: No LINK tokens to withdraw");
        LINK.transfer(msg.sender, balance);
    }

    function setKeyHash(bytes32 _keyHash) external onlyOwner {
        keyHash = _keyHash;
    }

    function setFee(uint256 _fee) external onlyOwner {
        fee = _fee;
    }
}
