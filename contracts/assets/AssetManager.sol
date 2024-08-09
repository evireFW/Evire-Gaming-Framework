// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title AssetManager
 * @dev This contract is responsible for managing game assets within the Evire gaming framework.
 * It handles registration, ownership tracking, and updates related to various assets.
 */
contract AssetManager is Ownable, AccessControl, Pausable, ReentrancyGuard {
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.UintSet;

    bytes32 public constant ASSET_MANAGER_ROLE = keccak256("ASSET_MANAGER_ROLE");

    struct Asset {
        uint256 assetId;
        uint256 assetTypeId;
        address owner;
        string metadataURI;
        bool exists;
    }

    Counters.Counter private _totalAssets;
    mapping(uint256 => Asset) private _assets;
    mapping(address => EnumerableSet.UintSet) private _ownedAssets;

    event AssetRegistered(uint256 indexed assetId, uint256 indexed assetTypeId, address indexed owner, string metadataURI);
    event AssetOwnershipTransferred(uint256 indexed assetId, address indexed previousOwner, address indexed newOwner);
    event AssetMetadataUpdated(uint256 indexed assetId, string previousMetadataURI, string newMetadataURI);
    event AssetUnregistered(uint256 indexed assetId, address indexed owner);

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ASSET_MANAGER_ROLE, msg.sender);
    }

    modifier onlyAssetOwner(uint256 assetId) {
        require(_assets[assetId].owner == msg.sender, "AssetManager: caller is not the asset owner");
        _;
    }

    modifier assetExists(uint256 assetId) {
        require(_assets[assetId].exists, "AssetManager: asset does not exist");
        _;
    }

    function registerAsset(uint256 assetId, uint256 assetTypeId, address owner) external onlyRole(ASSET_MANAGER_ROLE) whenNotPaused {
        require(!_assets[assetId].exists, "AssetManager: asset already registered");

        Asset memory newAsset = Asset({
            assetId: assetId,
            assetTypeId: assetTypeId,
            owner: owner,
            metadataURI: "",
            exists: true
        });

        _assets[assetId] = newAsset;
        _ownedAssets[owner].add(assetId);

        _totalAssets.increment();

        emit AssetRegistered(assetId, assetTypeId, owner, newAsset.metadataURI);
    }

    function updateAssetOwner(uint256 assetId, address newOwner) external onlyRole(ASSET_MANAGER_ROLE) assetExists(assetId) whenNotPaused {
        address previousOwner = _assets[assetId].owner;

        _ownedAssets[previousOwner].remove(assetId);
        _ownedAssets[newOwner].add(assetId);

        _assets[assetId].owner = newOwner;

        emit AssetOwnershipTransferred(assetId, previousOwner, newOwner);
    }

    function updateAssetMetadata(uint256 assetId, string memory newMetadataURI) external onlyRole(ASSET_MANAGER_ROLE) assetExists(assetId) whenNotPaused {
        string memory previousMetadataURI = _assets[assetId].metadataURI;
        _assets[assetId].metadataURI = newMetadataURI;

        emit AssetMetadataUpdated(assetId, previousMetadataURI, newMetadataURI);
    }

    function unregisterAsset(uint256 assetId) external onlyRole(ASSET_MANAGER_ROLE) assetExists(assetId) whenNotPaused {
        address owner = _assets[assetId].owner;

        _ownedAssets[owner].remove(assetId);
        delete _assets[assetId];

        _totalAssets.decrement();

        emit AssetUnregistered(assetId, owner);
    }

    function getAssetInfo(uint256 assetId) external view assetExists(assetId) returns (uint256, address, string memory) {
        Asset memory asset = _assets[assetId];
        return (asset.assetTypeId, asset.owner, asset.metadataURI);
    }

    function getOwnedAssets(address owner) external view returns (uint256[] memory) {
        uint256[] memory assetIds = new uint256[](_ownedAssets[owner].length());
        for (uint256 i = 0; i < _ownedAssets[owner].length(); i++) {
            assetIds[i] = _ownedAssets[owner].at(i);
        }
        return assetIds;
    }

    function getTotalAssets() external view returns (uint256) {
        return _totalAssets.current();
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function transferAssetOwnership(uint256 assetId, address from, address to) external onlyAssetOwner(assetId) assetExists(assetId) nonReentrant whenNotPaused {
        require(from == _assets[assetId].owner, "AssetManager: from address is not the current owner");
        require(to != address(0), "AssetManager: transfer to the zero address");

        _ownedAssets[from].remove(assetId);
        _ownedAssets[to].add(assetId);
        _assets[assetId].owner = to;

        emit AssetOwnershipTransferred(assetId, from, to);
    }

    function transferMultipleAssets(uint256[] calldata assetIds, address to) external nonReentrant whenNotPaused {
        require(to != address(0), "AssetManager: transfer to the zero address");

        for (uint256 i = 0; i < assetIds.length; i++) {
            uint256 assetId = assetIds[i];
            address from = _assets[assetId].owner;

            require(from == msg.sender, "AssetManager: caller is not the owner of one or more assets");

            _ownedAssets[from].remove(assetId);
            _ownedAssets[to].add(assetId);
            _assets[assetId].owner = to;

            emit AssetOwnershipTransferred(assetId, from, to);
        }
    }

    function batchUpdateAssetMetadata(uint256[] calldata assetIds, string[] calldata metadataURIs) external onlyRole(ASSET_MANAGER_ROLE) whenNotPaused {
        require(assetIds.length == metadataURIs.length, "AssetManager: assetIds and metadataURIs length mismatch");

        for (uint256 i = 0; i < assetIds.length; i++) {
            uint256 assetId = assetIds[i];
            require(_assets[assetId].exists, "AssetManager: one or more assets do not exist");

            string memory previousMetadataURI = _assets[assetId].metadataURI;
            _assets[assetId].metadataURI = metadataURIs[i];

            emit AssetMetadataUpdated(assetId, previousMetadataURI, metadataURIs[i]);
        }
    }

    function batchRegisterAssets(uint256[] calldata assetIds, uint256[] calldata assetTypeIds, address[] calldata owners) external onlyRole(ASSET_MANAGER_ROLE) whenNotPaused {
        require(assetIds.length == assetTypeIds.length && assetIds.length == owners.length, "AssetManager: Input arrays length mismatch");

        for (uint256 i = 0; i < assetIds.length; i++) {
            require(!_assets[assetIds[i]].exists, "AssetManager: one or more assets are already registered");

            Asset memory newAsset = Asset({
                assetId: assetIds[i],
                assetTypeId: assetTypeIds[i],
                owner: owners[i],
                metadataURI: "",
                exists: true
            });

            _assets[assetIds[i]] = newAsset;
            _ownedAssets[owners[i]].add(assetIds[i]);

            _totalAssets.increment();

            emit AssetRegistered(assetIds[i], assetTypeIds[i], owners[i], newAsset.metadataURI);
        }
    }

    function batchUnregisterAssets(uint256[] calldata assetIds) external onlyRole(ASSET_MANAGER_ROLE) whenNotPaused {
        for (uint256 i = 0; i < assetIds.length; i++) {
            require(_assets[assetIds[i]].exists, "AssetManager: one or more assets do not exist");

            address owner = _assets[assetIds[i]].owner;

            _ownedAssets[owner].remove(assetIds[i]);
            delete _assets[assetIds[i]];

            _totalAssets.decrement();

            emit AssetUnregistered(assetIds[i], owner);
        }
    }
}
