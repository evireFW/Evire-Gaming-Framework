// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

contract WeatherOracle is Initializable, AccessControlUpgradeable, PausableUpgradeable, UUPSUpgradeable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;

    bytes32 public constant UPDATER_ROLE = keccak256("UPDATER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    struct WeatherData {
        int256 temperature; // Temperature in Celsius, multiplied by 100 (e.g., 2500 = 25.00°C)
        uint256 humidity; // Humidity percentage, from 0 to 100
        uint256 windSpeed; // Wind speed in km/h, multiplied by 10 (e.g., 155 = 15.5 km/h)
        uint256 precipitation; // Precipitation in mm, multiplied by 10 (e.g., 25 = 2.5 mm)
        uint256 lastUpdated; // Timestamp of the last update
    }

    mapping(bytes32 => WeatherData) private weatherDataByLocation;
    EnumerableSetUpgradeable.Bytes32Set private locations;

    AggregatorV3Interface private temperatureFeed;
    AggregatorV3Interface private precipitationFeed;

    uint256 public constant UPDATE_INTERVAL = 1 hours;
    uint256 public constant MAX_TEMPERATURE_CHANGE = 500; // 5°C
    uint256 public constant MAX_PRECIPITATION_CHANGE = 100; // 10 mm

    event WeatherUpdated(bytes32 indexed location, int256 temperature, uint256 humidity, uint256 windSpeed, uint256 precipitation);
    event ChainlinkDataUpdated(int256 temperature, uint256 precipitation);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _temperatureFeed, address _precipitationFeed) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPDATER_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        temperatureFeed = AggregatorV3Interface(_temperatureFeed);
        precipitationFeed = AggregatorV3Interface(_precipitationFeed);
    }

    function updateWeather(
        bytes32 _location,
        int256 _temperature,
        uint256 _humidity,
        uint256 _windSpeed,
        uint256 _precipitation
    ) external onlyRole(UPDATER_ROLE) whenNotPaused {
        require(_humidity <= 100, "Humidity must be between 0 and 100");
        require(_windSpeed <= 2000, "Wind speed must be <= 200 km/h");
        require(_precipitation <= 1000, "Precipitation must be <= 100 mm");

        WeatherData storage data = weatherDataByLocation[_location];

        if (data.lastUpdated != 0) {
            require(block.timestamp >= data.lastUpdated + UPDATE_INTERVAL, "Update interval not reached");
            require(abs(_temperature - data.temperature) <= MAX_TEMPERATURE_CHANGE, "Temperature change too large");
            require(abs(int256(_precipitation) - int256(data.precipitation)) <= MAX_PRECIPITATION_CHANGE, "Precipitation change too large");
        }

        data.temperature = _temperature;
        data.humidity = _humidity;
        data.windSpeed = _windSpeed;
        data.precipitation = _precipitation;
        data.lastUpdated = block.timestamp;

        if (!locations.contains(_location)) {
            locations.add(_location);
        }

        emit WeatherUpdated(_location, _temperature, _humidity, _windSpeed, _precipitation);
    }

    function getWeather(bytes32 _location) external view returns (WeatherData memory) {
        require(weatherDataByLocation[_location].lastUpdated != 0, "Weather data not available for this location");
        return weatherDataByLocation[_location];
    }

    function getLocations() external view returns (bytes32[] memory) {
        return locations.values();
    }

    function updateChainlinkData() external onlyRole(UPDATER_ROLE) whenNotPaused {
        (, int256 temperature,,,) = temperatureFeed.latestRoundData();
        (, int256 precipitation,,,) = precipitationFeed.latestRoundData();

        emit ChainlinkDataUpdated(temperature, uint256(precipitation));
    }

    function getChainlinkData() external view returns (int256 temperature, uint256 precipitation) {
        (, temperature,,,) = temperatureFeed.latestRoundData();
        (, int256 precip,,,) = precipitationFeed.latestRoundData();
        precipitation = uint256(precip);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    function abs(int256 x) private pure returns (int256) {
        return x >= 0 ? x : -x;
    }

    // TODO: Implement additional features such as:
    // - Historical weather data storage and retrieval
    // - Weather prediction based on historical data
    // - Integration with multiple weather data sources for increased reliability
    // - Automated weather updates based on geolocation
}