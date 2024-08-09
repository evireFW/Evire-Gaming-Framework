// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./KYC.sol";

contract ComplianceManager is AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant COMPLIANCE_OFFICER_ROLE = keccak256("COMPLIANCE_OFFICER_ROLE");

    KYC public kycContract;
    mapping(address => bool) public isBlacklisted;
    mapping(address => uint256) public lastComplianceCheck;

    event KYCUpdated(address indexed user, bool isVerified);
    event AddressBlacklisted(address indexed user);
    event AddressRemovedFromBlacklist(address indexed user);
    event ComplianceCheckPassed(address indexed user, uint256 timestamp);
    event ComplianceCheckFailed(address indexed user, string reason, uint256 timestamp);

    modifier onlyVerified(address user) {
        require(kycContract.isVerified(user), "ComplianceManager: user is not KYC verified");
        _;
    }

    modifier notBlacklisted(address user) {
        require(!isBlacklisted[user], "ComplianceManager: user is blacklisted");
        _;
    }

    constructor(address _kycContract) {
        kycContract = KYC(_kycContract);

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(COMPLIANCE_OFFICER_ROLE, msg.sender);
    }

    function updateKYCStatus(address user, bool status)
        external
        onlyRole(COMPLIANCE_OFFICER_ROLE)
    {
        kycContract.setKYCStatus(user, status);
        emit KYCUpdated(user, status);
    }

    function blacklistAddress(address user)
        external
        onlyRole(COMPLIANCE_OFFICER_ROLE)
    {
        isBlacklisted[user] = true;
        emit AddressBlacklisted(user);
    }

    function removeAddressFromBlacklist(address user)
        external
        onlyRole(COMPLIANCE_OFFICER_ROLE)
    {
        isBlacklisted[user] = false;
        emit AddressRemovedFromBlacklist(user);
    }

    function performComplianceCheck(address user)
        external
        onlyRole(COMPLIANCE_OFFICER_ROLE)
        notBlacklisted(user)
    {
        require(kycContract.isVerified(user), "ComplianceManager: KYC check failed");
        lastComplianceCheck[user] = block.timestamp;
        emit ComplianceCheckPassed(user, block.timestamp);
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function enforceCompliance(address user)
        external
        whenNotPaused
        onlyRole(COMPLIANCE_OFFICER_ROLE)
        notBlacklisted(user)
        onlyVerified(user)
    {
        require(block.timestamp - lastComplianceCheck[user] <= 30 days, "ComplianceManager: Compliance check outdated");

        // Placeholder for additional compliance logic
    }

    function withdraw(address tokenAddress, uint256 amount)
        external
        onlyRole(ADMIN_ROLE)
        nonReentrant
    {
        IERC20(tokenAddress).transfer(msg.sender, amount);
    }

    function batchBlacklistAddresses(address[] calldata users)
        external
        onlyRole(COMPLIANCE_OFFICER_ROLE)
    {
        for (uint256 i = 0; i < users.length; i++) {
            isBlacklisted[users[i]] = true;
            emit AddressBlacklisted(users[i]);
        }
    }

    function batchRemoveFromBlacklist(address[] calldata users)
        external
        onlyRole(COMPLIANCE_OFFICER_ROLE)
    {
        for (uint256 i = 0; i < users.length; i++) {
            isBlacklisted[users[i]] = false;
            emit AddressRemovedFromBlacklist(users[i]);
        }
    }

    function isCompliant(address user) external view returns (bool) {
        return kycContract.isVerified(user) && !isBlacklisted[user];
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
