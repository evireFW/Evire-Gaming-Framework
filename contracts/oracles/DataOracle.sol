// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract DataOracle is AccessControl, Pausable, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeMath for uint256;

    bytes32 public constant DATA_PROVIDER_ROLE = keccak256("DATA_PROVIDER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    struct DataFeed {
        string dataType;
        uint256 timestamp;
        bytes data;
        bool verified;
    }

    struct Validator {
        uint256 successfulValidations;
        uint256 totalValidations;
        bool isActive;
    }

    EnumerableSet.AddressSet private dataProviders;
    mapping(bytes32 => DataFeed) private dataFeeds;
    mapping(address => Validator) private validators;
    mapping(bytes32 => EnumerableSet.AddressSet) private dataFeedValidators;

    uint256 public validationThreshold;
    uint256 public requiredConfirmations;

    event DataFeedSubmitted(bytes32 indexed dataId, string dataType, uint256 timestamp);
    event DataFeedValidated(bytes32 indexed dataId, address indexed validator, bool isValid);
    event DataFeedConfirmed(bytes32 indexed dataId, bool confirmed);

    constructor(uint256 _validationThreshold, uint256 _requiredConfirmations) {
        _setupRole(ADMIN_ROLE, msg.sender);
        validationThreshold = _validationThreshold;
        requiredConfirmations = _requiredConfirmations;
    }

    modifier onlyDataProvider() {
        require(hasRole(DATA_PROVIDER_ROLE, msg.sender), "DataOracle: caller is not a data provider");
        _;
    }

    modifier onlyValidator() {
        require(validators[msg.sender].isActive, "DataOracle: caller is not an active validator");
        _;
    }

    function addDataProvider(address provider) external onlyRole(ADMIN_ROLE) {
        require(dataProviders.add(provider), "DataOracle: provider already added");
        _setupRole(DATA_PROVIDER_ROLE, provider);
    }

    function removeDataProvider(address provider) external onlyRole(ADMIN_ROLE) {
        require(dataProviders.remove(provider), "DataOracle: provider not found");
        revokeRole(DATA_PROVIDER_ROLE, provider);
    }

    function submitData(bytes32 dataId, string memory dataType, bytes memory data) external onlyDataProvider whenNotPaused nonReentrant {
        require(dataFeeds[dataId].timestamp == 0, "DataOracle: dataId already exists");

        dataFeeds[dataId] = DataFeed({
            dataType: dataType,
            timestamp: block.timestamp,
            data: data,
            verified: false
        });

        emit DataFeedSubmitted(dataId, dataType, block.timestamp);
    }

    function validateData(bytes32 dataId, bool isValid) external onlyValidator whenNotPaused nonReentrant {
        require(dataFeeds[dataId].timestamp != 0, "DataOracle: dataId does not exist");
        require(!dataFeeds[dataId].verified, "DataOracle: data already verified");
        require(!dataFeedValidators[dataId].contains(msg.sender), "DataOracle: validator already submitted for this data");

        dataFeedValidators[dataId].add(msg.sender);

        Validator storage validator = validators[msg.sender];
        validator.totalValidations++;
        if (isValid) {
            validator.successfulValidations++;
        }

        emit DataFeedValidated(dataId, msg.sender, isValid);

        if (dataFeedValidators[dataId].length() >= requiredConfirmations) {
            _confirmDataFeed(dataId);
        }
    }

    function _confirmDataFeed(bytes32 dataId) internal {
        uint256 validCount = 0;
        EnumerableSet.AddressSet storage feedValidators = dataFeedValidators[dataId];

        for (uint256 i = 0; i < feedValidators.length(); i++) {
            address validatorAddress = feedValidators.at(i);
            if (validators[validatorAddress].successfulValidations >= validationThreshold) {
                validCount++;
            }
        }

        if (validCount >= requiredConfirmations) {
            dataFeeds[dataId].verified = true;
            emit DataFeedConfirmed(dataId, true);
        } else {
            emit DataFeedConfirmed(dataId, false);
        }
    }

    function getData(bytes32 dataId) external view returns (string memory, uint256, bytes memory, bool) {
        DataFeed storage dataFeed = dataFeeds[dataId];
        require(dataFeed.timestamp != 0, "DataOracle: dataId does not exist");

        return (dataFeed.dataType, dataFeed.timestamp, dataFeed.data, dataFeed.verified);
    }

    function addValidator(address validatorAddress) external onlyRole(ADMIN_ROLE) {
        require(!validators[validatorAddress].isActive, "DataOracle: validator already active");

        validators[validatorAddress].isActive = true;
    }

    function removeValidator(address validatorAddress) external onlyRole(ADMIN_ROLE) {
        require(validators[validatorAddress].isActive, "DataOracle: validator not active");

        validators[validatorAddress].isActive = false;
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function updateValidationThreshold(uint256 newThreshold) external onlyRole(ADMIN_ROLE) {
        validationThreshold = newThreshold;
    }

    function updateRequiredConfirmations(uint256 newConfirmations) external onlyRole(ADMIN_ROLE) {
        requiredConfirmations = newConfirmations;
    }

    function isDataProvider(address provider) external view returns (bool) {
        return dataProviders.contains(provider);
    }

    function isValidator(address validatorAddress) external view returns (bool) {
        return validators[validatorAddress].isActive;
    }

    function getValidatorInfo(address validatorAddress) external view returns (uint256, uint256, bool) {
        Validator storage validator = validators[validatorAddress];
        return (validator.successfulValidations, validator.totalValidations, validator.isActive);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
