// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../libraries/GameLibrary.sol";
import "../core/GameManager.sol";
import "./AssetManager.sol";
import "./NFTAsset.sol";

contract AssetFactory is AccessControl, ReentrancyGuard {
    using Counters for Counters.Counter;

    bytes32 public constant GAME_MANAGER_ROLE = keccak256("GAME_MANAGER_ROLE");
    bytes32 public constant ASSET_CREATOR_ROLE = keccak256("ASSET_CREATOR_ROLE");

    Counters.Counter private _assetTypeIds;
    Counters.Counter private _assetIds;

    GameManager public gameManager;
    AssetManager public assetManager;

    struct AssetType {
        uint256 id;
        string name;
        string category;
        uint256 maxSupply;
        uint256 currentSupply;
        bool transferable;
        bool burnable;
    }

    mapping(uint256 => AssetType) public assetTypes;

    mapping(uint256 => address) public assetContracts;

    mapping(address => bool) public gameContracts;

    event AssetTypeCreated(uint256 indexed assetTypeId, string name, string category, uint256 maxSupply);
    event AssetCreated(uint256 indexed assetId, uint256 indexed assetTypeId, address indexed owner);
    event AssetTransferred(uint256 indexed assetId, address indexed from, address indexed to);
    event AssetBurned(uint256 indexed assetId, address indexed owner);

    constructor(address _gameManager, address _assetManager) {
        gameManager = GameManager(_gameManager);
        assetManager = AssetManager(_assetManager);

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(GAME_MANAGER_ROLE, _gameManager);
        _setupRole(ASSET_CREATOR_ROLE, msg.sender);
    }

    modifier onlyGameContract() {
        require(gameContracts[msg.sender], "AssetFactory: caller is not a registered game contract");
        _;
    }

    function createAssetType(
        string memory name,
        string memory category,
        uint256 maxSupply,
        bool transferable,
        bool burnable
    ) external onlyRole(ASSET_CREATOR_ROLE) returns (uint256) {
        _assetTypeIds.increment();
        uint256 newAssetTypeId = _assetTypeIds.current();

        AssetType memory newAssetType = AssetType({
            id: newAssetTypeId,
            name: name,
            category: category,
            maxSupply: maxSupply,
            currentSupply: 0,
            transferable: transferable,
            burnable: burnable
        });

        assetTypes[newAssetTypeId] = newAssetType;

        address newAssetContract = address(new NFTAsset(name, "EVIRE", address(this)));
        assetContracts[newAssetTypeId] = newAssetContract;

        emit AssetTypeCreated(newAssetTypeId, name, category, maxSupply);

        return newAssetTypeId;
    }

    function mintAsset(uint256 assetTypeId, address to, string memory tokenURI)
        external
        onlyGameContract
        nonReentrant
        returns (uint256)
    {
        AssetType storage assetType = assetTypes[assetTypeId];
        require(assetType.id != 0, "AssetFactory: asset type does not exist");
        require(assetType.currentSupply < assetType.maxSupply, "AssetFactory: max supply reached");

        _assetIds.increment();
        uint256 newAssetId = _assetIds.current();

        NFTAsset(assetContracts[assetTypeId]).safeMint(to, newAssetId, tokenURI);

        assetType.currentSupply++;

        assetManager.registerAsset(newAssetId, assetTypeId, to);

        emit AssetCreated(newAssetId, assetTypeId, to);

        return newAssetId;
    }

    function transferAsset(uint256 assetId, address from, address to)
        external
        onlyGameContract
    {
        (uint256 assetTypeId, ) = assetManager.getAssetInfo(assetId);
        AssetType memory assetType = assetTypes[assetTypeId];
        require(assetType.transferable, "AssetFactory: asset is not transferable");

        NFTAsset(assetContracts[assetTypeId]).safeTransferFrom(from, to, assetId);
        assetManager.updateAssetOwner(assetId, to);

        emit AssetTransferred(assetId, from, to);
    }

    function burnAsset(uint256 assetId)
        external
        onlyGameContract
    {
        (uint256 assetTypeId, address owner) = assetManager.getAssetInfo(assetId);
        AssetType storage assetType = assetTypes[assetTypeId];
        require(assetType.burnable, "AssetFactory: asset is not burnable");

        NFTAsset(assetContracts[assetTypeId]).burn(assetId);
        assetManager.unregisterAsset(assetId);

        assetType.currentSupply--;

        emit AssetBurned(assetId, owner);
    }

    function registerGameContract(address gameContract)
        external
        onlyRole(GAME_MANAGER_ROLE)
    {
        gameContracts[gameContract] = true;
    }

    function unregisterGameContract(address gameContract)
        external
        onlyRole(GAME_MANAGER_ROLE)
    {
        gameContracts[gameContract] = false;
    }

    function getAssetType(uint256 assetTypeId) external view returns (AssetType memory) {
        return assetTypes[assetTypeId];
    }

    function getAssetContract(uint256 assetTypeId) external view returns (address) {
        return assetContracts[assetTypeId];
    }

    function isGameContract(address account) external view returns (bool) {
        return gameContracts[account];
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}