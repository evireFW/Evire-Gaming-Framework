// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract AMLChecks is Initializable, AccessControlUpgradeable, PausableUpgradeable, UUPSUpgradeable {
    bytes32 public constant COMPLIANCE_OFFICER_ROLE = keccak256("COMPLIANCE_OFFICER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    uint256 public constant DAILY_TRANSACTION_LIMIT = 10000 * 10**18; // 10,000 tokens
    uint256 public constant MONTHLY_TRANSACTION_LIMIT = 100000 * 10**18; // 100,000 tokens

    struct UserTransactions {
        uint256 dailyTotal;
        uint256 monthlyTotal;
        uint256 lastDailyReset;
        uint256 lastMonthlyReset;
    }

    mapping(address => UserTransactions) private userTransactions;
    mapping(address => bool) private blacklistedAddresses;

    event TransactionFlagged(address indexed user, uint256 amount, string reason);
    event AddressBlacklisted(address indexed user);
    event AddressWhitelisted(address indexed user);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(COMPLIANCE_OFFICER_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
    }

    function checkTransaction(address user, uint256 amount) public whenNotPaused returns (bool) {
        require(!blacklistedAddresses[user], "AMLChecks: User is blacklisted");

        UserTransactions storage userTxs = userTransactions[user];

        // Reset daily and monthly totals if necessary
        if (block.timestamp - userTxs.lastDailyReset >= 1 days) {
            userTxs.dailyTotal = 0;
            userTxs.lastDailyReset = block.timestamp;
        }
        if (block.timestamp - userTxs.lastMonthlyReset >= 30 days) {
            userTxs.monthlyTotal = 0;
            userTxs.lastMonthlyReset = block.timestamp;
        }

        // Check against limits
        if (userTxs.dailyTotal + amount > DAILY_TRANSACTION_LIMIT) {
            emit TransactionFlagged(user, amount, "Daily limit exceeded");
            return false;
        }
        if (userTxs.monthlyTotal + amount > MONTHLY_TRANSACTION_LIMIT) {
            emit TransactionFlagged(user, amount, "Monthly limit exceeded");
            return false;
        }

        // Update totals
        userTxs.dailyTotal += amount;
        userTxs.monthlyTotal += amount;

        return true;
    }

    function blacklistAddress(address user) public onlyRole(COMPLIANCE_OFFICER_ROLE) {
        blacklistedAddresses[user] = true;
        emit AddressBlacklisted(user);
    }

    function whitelistAddress(address user) public onlyRole(COMPLIANCE_OFFICER_ROLE) {
        blacklistedAddresses[user] = false;
        emit AddressWhitelisted(user);
    }

    function isBlacklisted(address user) public view returns (bool) {
        return blacklistedAddresses[user];
    }

    function getUserTransactionTotals(address user) public view returns (uint256 daily, uint256 monthly) {
        UserTransactions storage userTxs = userTransactions[user];
        return (userTxs.dailyTotal, userTxs.monthlyTotal);
    }

    function pause() public onlyRole(COMPLIANCE_OFFICER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(COMPLIANCE_OFFICER_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(UPGRADER_ROLE)
        override
    {}

    // TODO: Implement better AML checks, such as:
    // - Pattern recognition for suspicious transaction sequences
    // - Integration with external AML data providers
    // - Automated reporting for suspicious activities
}