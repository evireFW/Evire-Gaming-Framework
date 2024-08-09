// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract PriceOracle is AccessControl, Pausable, ReentrancyGuard {
    using SafeMath for uint256;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPDATER_ROLE = keccak256("UPDATER_ROLE");

    struct PriceData {
        uint256 price;
        uint256 lastUpdated;
        bool exists;
    }

    struct PriceSource {
        address source;
        bool active;
        uint256 lastUpdated;
    }

    mapping(bytes32 => PriceData) private prices;
    mapping(bytes32 => PriceSource[]) private priceSources;
    uint256 public updateInterval;
    uint256 public stalePriceThreshold;

    event PriceUpdated(bytes32 indexed asset, uint256 price, address indexed updatedBy, uint256 timestamp);
    event PriceSourceAdded(bytes32 indexed asset, address indexed source, uint256 timestamp);
    event PriceSourceRemoved(bytes32 indexed asset, address indexed source, uint256 timestamp);

    constructor(uint256 _updateInterval, uint256 _stalePriceThreshold) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(UPDATER_ROLE, msg.sender);

        updateInterval = _updateInterval;
        stalePriceThreshold = _stalePriceThreshold;
    }

    function addPriceSource(bytes32 asset, address source) external onlyRole(ADMIN_ROLE) {
        require(source != address(0), "PriceOracle: source cannot be the zero address");
        PriceSource memory newSource = PriceSource({
            source: source,
            active: true,
            lastUpdated: block.timestamp
        });
        priceSources[asset].push(newSource);
        emit PriceSourceAdded(asset, source, block.timestamp);
    }

    function removePriceSource(bytes32 asset, address source) external onlyRole(ADMIN_ROLE) {
        PriceSource[] storage sources = priceSources[asset];
        for (uint256 i = 0; i < sources.length; i++) {
            if (sources[i].source == source) {
                sources[i].active = false;
                emit PriceSourceRemoved(asset, source, block.timestamp);
                break;
            }
        }
    }

    function updatePrice(bytes32 asset, uint256 price) external onlyRole(UPDATER_ROLE) whenNotPaused nonReentrant {
        require(price > 0, "PriceOracle: price must be greater than 0");

        PriceSource[] storage sources = priceSources[asset];
        require(sources.length > 0, "PriceOracle: no sources available for this asset");

        bool validSource = false;
        for (uint256 i = 0; i < sources.length; i++) {
            if (sources[i].source == msg.sender && sources[i].active) {
                sources[i].lastUpdated = block.timestamp;
                validSource = true;
                break;
            }
        }
        require(validSource, "PriceOracle: unauthorized or inactive source");

        PriceData storage data = prices[asset];
        data.price = calculateAveragePrice(asset, price);
        data.lastUpdated = block.timestamp;
        data.exists = true;

        emit PriceUpdated(asset, data.price, msg.sender, block.timestamp);
    }

    function calculateAveragePrice(bytes32 asset, uint256 newPrice) internal view returns (uint256) {
        PriceSource[] storage sources = priceSources[asset];
        uint256 totalValidSources = 0;
        uint256 aggregatedPrice = 0;

        for (uint256 i = 0; i < sources.length; i++) {
            if (sources[i].active && (block.timestamp.sub(sources[i].lastUpdated) <= stalePriceThreshold)) {
                aggregatedPrice = aggregatedPrice.add(prices[asset].price);
                totalValidSources++;
            }
        }

        if (totalValidSources > 0) {
            aggregatedPrice = aggregatedPrice.add(newPrice);
            return aggregatedPrice.div(totalValidSources.add(1)); // Including the new price
        } else {
            return newPrice; // Only new price is considered if no valid sources
        }
    }

    function getPrice(bytes32 asset) external view returns (uint256) {
        require(prices[asset].exists, "PriceOracle: asset price not available");
        return prices[asset].price;
    }

    function getPriceWithTimestamp(bytes32 asset) external view returns (uint256, uint256) {
        require(prices[asset].exists, "PriceOracle: asset price not available");
        return (prices[asset].price, prices[asset].lastUpdated);
    }

    function isPriceStale(bytes32 asset) external view returns (bool) {
        if (!prices[asset].exists) return true;
        return block.timestamp.sub(prices[asset].lastUpdated) > stalePriceThreshold;
    }

    function setUpdateInterval(uint256 interval) external onlyRole(ADMIN_ROLE) {
        updateInterval = interval;
    }

    function setStalePriceThreshold(uint256 threshold) external onlyRole(ADMIN_ROLE) {
        stalePriceThreshold = threshold;
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
