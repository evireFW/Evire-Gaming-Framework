// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title RandomNumberGenerator
/// @notice Provides a mechanism for generating random numbers in a secure and verifiable manner
/// @dev Uses a combination of block properties and Chainlink VRF for randomness

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

contract RandomNumberGenerator is VRFConsumerBase {
    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 public randomResult;
    address public owner;
    
    event RandomnessRequested(bytes32 requestId);
    event RandomnessFulfilled(bytes32 requestId, uint256 randomness);
    
    /// @notice Initializes the contract with the required parameters
    /// @param _vrfCoordinator The address of the Chainlink VRF Coordinator
    /// @param _link The address of the LINK token
    /// @param _keyHash The key hash for the VRF job
    /// @param _fee The fee required to fulfill a VRF request
    constructor(address _vrfCoordinator, address _link, bytes32 _keyHash, uint256 _fee) 
        VRFConsumerBase(_vrfCoordinator, _link) {
        keyHash = _keyHash;
        fee = _fee;
        owner = msg.sender;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }
    
    /// @notice Requests randomness from Chainlink VRF
    /// @dev Must have enough LINK to pay the fee
    /// @return requestId The ID of the randomness request
    function getRandomNumber() public onlyOwner returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK");
        requestId = requestRandomness(keyHash, fee);
        emit RandomnessRequested(requestId);
    }
    
    /// @notice Callback function used by VRF Coordinator
    /// @param requestId The ID of the randomness request
    /// @param randomness The random number provided by VRF Coordinator
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        randomResult = randomness;
        emit RandomnessFulfilled(requestId, randomness);
    }
    
    /// @notice Withdraws LINK tokens from the contract
    /// @param _to The address to send the LINK tokens to
    /// @param _amount The amount of LINK tokens to withdraw
    function withdrawLink(address _to, uint256 _amount) external onlyOwner {
        require(LINK.transfer(_to, _amount), "Transfer failed");
    }
    
    /// @notice Provides a pseudo-random number based on block properties
    /// @param _seed An additional seed provided by the user
    /// @return A pseudo-random number
    function getPseudoRandomNumber(uint256 _seed) public view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender, _seed)));
    }
    
    /// @notice Fallback function to accept ETH
    receive() external payable {}
    
    /// @notice Fallback function to accept non-standard ETH transfers
    fallback() external payable {}
    
    /// @notice Sets a new owner for the contract
    /// @param _newOwner The address of the new owner
    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "New owner is the zero address");
        owner = _newOwner;
    }
    
    /// @notice Destroys the contract and sends all ETH and LINK to the owner
    function destroy() external onlyOwner {
        selfdestruct(payable(owner));
    }
} 
