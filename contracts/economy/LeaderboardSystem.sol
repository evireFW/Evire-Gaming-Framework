// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

contract RewardSystem is Initializable, AccessControlUpgradeable, PausableUpgradeable, UUPSUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    bytes32 public constant GAME_MANAGER_ROLE = keccak256("GAME_MANAGER_ROLE");
    bytes32 public constant REWARD_DISTRIBUTOR_ROLE = keccak256("REWARD_DISTRIBUTOR_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    enum RewardType { TOKEN, NFT, INGAME_ITEM }

    struct Reward {
        RewardType rewardType;
        address tokenAddress;
        uint256 tokenId;
        uint256 amount;
        string metadata;
        bool isActive;
    }

    mapping(uint256 => Reward) private rewards;
    CountersUpgradeable.Counter private rewardIdCounter;

    mapping(address => mapping(uint256 => bool)) private claimedRewards;

    event RewardCreated(uint256 indexed rewardId, RewardType rewardType, address tokenAddress, uint256 tokenId, uint256 amount);
    event RewardClaimed(address indexed player, uint256 indexed rewardId);
    event RewardUpdated(uint256 indexed rewardId, bool isActive);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(GAME_MANAGER_ROLE, msg.sender);
        _grantRole(REWARD_DISTRIBUTOR_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
    }

    function createReward(
        RewardType rewardType,
        address tokenAddress,
        uint256 tokenId,
        uint256 amount,
        string memory metadata
    ) public onlyRole(GAME_MANAGER_ROLE) returns (uint256) {
        uint256 rewardId = rewardIdCounter.current();
        rewards[rewardId] = Reward(rewardType, tokenAddress, tokenId, amount, metadata, true);
        rewardIdCounter.increment();

        emit RewardCreated(rewardId, rewardType, tokenAddress, tokenId, amount);
        return rewardId;
    }

    function updateRewardStatus(uint256 rewardId, bool isActive) public onlyRole(GAME_MANAGER_ROLE) {
        require(rewards[rewardId].tokenAddress != address(0), "RewardSystem: Reward does not exist");
        rewards[rewardId].isActive = isActive;
        emit RewardUpdated(rewardId, isActive);
    }

    function claimReward(address player, uint256 rewardId) public onlyRole(REWARD_DISTRIBUTOR_ROLE) whenNotPaused {
        require(rewards[rewardId].tokenAddress != address(0), "RewardSystem: Reward does not exist");
        require(rewards[rewardId].isActive, "RewardSystem: Reward is not active");
        require(!claimedRewards[player][rewardId], "RewardSystem: Reward already claimed");

        Reward storage reward = rewards[rewardId];
        claimedRewards[player][rewardId] = true;

        if (reward.rewardType == RewardType.TOKEN) {
            require(IERC20Upgradeable(reward.tokenAddress).transfer(player, reward.amount), "RewardSystem: Token transfer failed");
        } else if (reward.rewardType == RewardType.NFT) {
            IERC721Upgradeable(reward.tokenAddress).safeTransferFrom(address(this), player, reward.tokenId);
        } else if (reward.rewardType == RewardType.INGAME_ITEM) {
            IERC1155Upgradeable(reward.tokenAddress).safeTransferFrom(address(this), player, reward.tokenId, reward.amount, "");
        }

        emit RewardClaimed(player, rewardId);
    }

    function getReward(uint256 rewardId) public view returns (Reward memory) {
        require(rewards[rewardId].tokenAddress != address(0), "RewardSystem: Reward does not exist");
        return rewards[rewardId];
    }

    function hasClaimedReward(address player, uint256 rewardId) public view returns (bool) {
        return claimedRewards[player][rewardId];
    }

    function pause() public onlyRole(GAME_MANAGER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(GAME_MANAGER_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(UPGRADER_ROLE)
        override
    {}

    // Required overrides for ERC1155 receiver
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    // Required override for ERC721 receiver
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC721Received.selector;
    }

    // TODO: Implement additional features such as:
    // - Time-limited rewards
    // - Reward pools with probabilistic distribution
    // - Bulk reward claiming for gas efficiency
    // - Integration with achievement system
    // - Reward analytics and reporting
}