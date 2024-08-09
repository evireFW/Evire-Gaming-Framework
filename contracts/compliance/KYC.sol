// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../libraries/DataValidation.sol";

contract KYC is AccessControl, ReentrancyGuard {
    using Address for address;
    using EnumerableSet for EnumerableSet.AddressSet;
    using Counters for Counters.Counter;

    bytes32 public constant KYC_ADMIN_ROLE = keccak256("KYC_ADMIN_ROLE");
    bytes32 public constant KYC_VERIFIER_ROLE = keccak256("KYC_VERIFIER_ROLE");

    struct KYCData {
        string fullName;
        string documentHash;
        bool isVerified;
        bool isRevoked;
        uint256 verificationTime;
        uint256 revocationTime;
    }

    struct Document {
        string docType;
        string docHash;
        uint256 uploadTime;
    }

    Counters.Counter private _userIds;
    mapping(address => uint256) private _userToId;
    mapping(uint256 => KYCData) private _kycData;
    mapping(uint256 => Document[]) private _userDocuments;

    EnumerableSet.AddressSet private _verifiedUsers;

    event KYCSubmitted(address indexed user, uint256 indexed userId);
    event KYCVerified(address indexed user, uint256 indexed userId);
    event KYCRevoked(address indexed user, uint256 indexed userId);
    event DocumentUploaded(address indexed user, uint256 indexed userId, string docType, string docHash);

    modifier onlyVerifiedUser(address user) {
        require(isVerified(user), "KYC: User is not verified");
        _;
    }

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(KYC_ADMIN_ROLE, msg.sender);
    }

    function submitKYC(string memory fullName, string memory documentHash) external nonReentrant {
        require(_userToId[msg.sender] == 0, "KYC: KYC already submitted");

        _userIds.increment();
        uint256 newUserId = _userIds.current();

        KYCData memory newKYCData = KYCData({
            fullName: fullName,
            documentHash: documentHash,
            isVerified: false,
            isRevoked: false,
            verificationTime: 0,
            revocationTime: 0
        });

        _userToId[msg.sender] = newUserId;
        _kycData[newUserId] = newKYCData;

        emit KYCSubmitted(msg.sender, newUserId);
    }

    function verifyKYC(address user) external onlyRole(KYC_VERIFIER_ROLE) nonReentrant {
        uint256 userId = _userToId[user];
        require(userId != 0, "KYC: User has not submitted KYC");
        require(!_kycData[userId].isVerified, "KYC: Already verified");

        _kycData[userId].isVerified = true;
        _kycData[userId].verificationTime = block.timestamp;

        _verifiedUsers.add(user);

        emit KYCVerified(user, userId);
    }

    function revokeKYC(address user) external onlyRole(KYC_ADMIN_ROLE) nonReentrant {
        uint256 userId = _userToId[user];
        require(userId != 0, "KYC: User has not submitted KYC");
        require(_kycData[userId].isVerified, "KYC: Not verified");
        require(!_kycData[userId].isRevoked, "KYC: Already revoked");

        _kycData[userId].isRevoked = true;
        _kycData[userId].revocationTime = block.timestamp;

        _verifiedUsers.remove(user);

        emit KYCRevoked(user, userId);
    }

    function uploadDocument(string memory docType, string memory docHash) external onlyVerifiedUser(msg.sender) nonReentrant {
        uint256 userId = _userToId[msg.sender];
        require(userId != 0, "KYC: User has not submitted KYC");

        Document memory newDocument = Document({
            docType: docType,
            docHash: docHash,
            uploadTime: block.timestamp
        });

        _userDocuments[userId].push(newDocument);

        emit DocumentUploaded(msg.sender, userId, docType, docHash);
    }

    function getKYCData(address user) external view returns (KYCData memory) {
        uint256 userId = _userToId[user];
        require(userId != 0, "KYC: User has not submitted KYC");
        return _kycData[userId];
    }

    function getUserDocuments(address user) external view returns (Document[] memory) {
        uint256 userId = _userToId[user];
        require(userId != 0, "KYC: User has not submitted KYC");
        return _userDocuments[userId];
    }

    function isVerified(address user) public view returns (bool) {
        return _verifiedUsers.contains(user);
    }

    function getVerifiedUsers() external view returns (address[] memory) {
        return _verifiedUsers.values();
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function withdrawERC20(IERC20 token, uint256 amount) external onlyRole(KYC_ADMIN_ROLE) {
        require(token.transfer(msg.sender, amount), "KYC: Transfer failed");
    }
}
