// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title NFTAsset
 * @dev ERC721 contract for handling non-fungible tokens within the Evire gaming framework.
 * Supports minting, burning, batch transfers, and royalties with advanced access control.
 */
contract NFTAsset is ERC721Enumerable, ERC721Burnable, AccessControl, ReentrancyGuard {
    using Counters for Counters.Counter;
    using Strings for uint256;

    // Role identifiers
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    Counters.Counter private _tokenIds;
    string private _baseTokenURI;

    struct RoyaltyInfo {
        address recipient;
        uint256 percentage; // in basis points (10000 = 100%)
    }

    mapping(uint256 => RoyaltyInfo) private _royalties;
    mapping(uint256 => uint256) private _lastTransferTimestamp;
    mapping(uint256 => uint256) private _tokenPrices;

    event TokenMinted(uint256 indexed tokenId, address indexed owner, string tokenURI);
    event RoyaltySet(uint256 indexed tokenId, address indexed recipient, uint256 percentage);
    event TokenListed(uint256 indexed tokenId, uint256 price);
    event TokenSold(uint256 indexed tokenId, address indexed from, address indexed to, uint256 price);

    constructor(string memory name, string memory symbol, address admin) ERC721(name, symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(ADMIN_ROLE, admin);
    }

    function setBaseURI(string memory baseURI) external onlyRole(ADMIN_ROLE) {
        _baseTokenURI = baseURI;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function safeMint(address to, uint256 tokenId, string memory tokenURI) external onlyRole(MINTER_ROLE) nonReentrant {
        require(!_exists(tokenId), "NFTAsset: Token ID already exists");
        _tokenIds.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenURI);
        emit TokenMinted(tokenId, to, tokenURI);
    }

    function batchMint(address to, uint256[] memory tokenIds, string[] memory tokenURIs) external onlyRole(MINTER_ROLE) nonReentrant {
        require(tokenIds.length == tokenURIs.length, "NFTAsset: tokenIds and tokenURIs length mismatch");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            safeMint(to, tokenIds[i], tokenURIs[i]);
        }
    }

    function setTokenPrice(uint256 tokenId, uint256 price) external {
        require(ownerOf(tokenId) == msg.sender, "NFTAsset: Caller is not the owner");
        _tokenPrices[tokenId] = price;
        emit TokenListed(tokenId, price);
    }

    function buyToken(uint256 tokenId) external payable nonReentrant {
        uint256 price = _tokenPrices[tokenId];
        require(price > 0, "NFTAsset: Token is not for sale");
        require(msg.value >= price, "NFTAsset: Insufficient payment");

        address seller = ownerOf(tokenId);
        _safeTransfer(seller, msg.sender, tokenId, "");

        uint256 royaltyAmount = 0;
        RoyaltyInfo memory royalty = _royalties[tokenId];
        if (royalty.recipient != address(0) && royalty.percentage > 0) {
            royaltyAmount = (price * royalty.percentage) / 10000;
            payable(royalty.recipient).transfer(royaltyAmount);
        }

        payable(seller).transfer(price - royaltyAmount);
        emit TokenSold(tokenId, seller, msg.sender, price);

        _tokenPrices[tokenId] = 0;
    }

    function setRoyalty(uint256 tokenId, address recipient, uint256 percentage) external onlyRole(ADMIN_ROLE) {
        require(_exists(tokenId), "NFTAsset: Nonexistent token");
        require(percentage <= 1000, "NFTAsset: Royalty percentage too high"); // max 10%
        _royalties[tokenId] = RoyaltyInfo(recipient, percentage);
        emit RoyaltySet(tokenId, recipient, percentage);
    }

    function getRoyaltyInfo(uint256 tokenId) external view returns (address recipient, uint256 percentage) {
        RoyaltyInfo memory royalty = _royalties[tokenId];
        return (royalty.recipient, royalty.percentage);
    }

    function batchTransferFrom(address from, address to, uint256[] memory tokenIds) external nonReentrant {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            transferFrom(from, to, tokenIds[i]);
        }
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Enumerable, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function withdrawERC20(IERC20 token, uint256 amount) external onlyRole(ADMIN_ROLE) {
        require(token.transfer(msg.sender, amount), "NFTAsset: Transfer failed");
    }

    function withdrawERC721(IERC721 token, uint256 tokenId) external onlyRole(ADMIN_ROLE) {
        token.safeTransferFrom(address(this), msg.sender, tokenId);
    }

    function withdrawETH(uint256 amount) external onlyRole(ADMIN_ROLE) {
        require(amount <= address(this).balance, "NFTAsset: Insufficient balance");
        payable(msg.sender).transfer(amount);
    }
}
