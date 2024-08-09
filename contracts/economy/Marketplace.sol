// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract Marketplace is AccessControl, ReentrancyGuard, Pausable {
    using EnumerableSet for EnumerableSet.UintSet;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");

    IERC20 public immutable paymentToken;
    uint256 public marketplaceFee; // Fee percentage in basis points (100 = 1%)

    struct Listing {
        uint256 id;
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        bool sold;
        bool cancelled;
    }

    uint256 private _listingIdCounter;
    mapping(uint256 => Listing) public listings;
    mapping(address => EnumerableSet.UintSet) private _userListings;

    event ListingCreated(uint256 indexed listingId, address indexed seller, address indexed nftContract, uint256 tokenId, uint256 price);
    event ListingCancelled(uint256 indexed listingId, address indexed seller);
    event ListingSold(uint256 indexed listingId, address indexed buyer, uint256 price);
    event MarketplaceFeeUpdated(uint256 oldFee, uint256 newFee);

    constructor(address _paymentToken, uint256 _marketplaceFee) {
        require(_paymentToken != address(0), "Marketplace: payment token address cannot be zero");
        require(_marketplaceFee <= 10000, "Marketplace: fee cannot exceed 100%");

        paymentToken = IERC20(_paymentToken);
        marketplaceFee = _marketplaceFee;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(FEE_MANAGER_ROLE, msg.sender);
    }

    modifier onlySeller(uint256 listingId) {
        require(listings[listingId].seller == msg.sender, "Marketplace: caller is not the seller");
        _;
    }

    modifier onlyExistingListing(uint256 listingId) {
        require(listings[listingId].id == listingId, "Marketplace: listing does not exist");
        _;
    }

    function createListing(address nftContract, uint256 tokenId, uint256 price) external nonReentrant whenNotPaused {
        require(price > 0, "Marketplace: price must be greater than zero");
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "Marketplace: caller is not the token owner");
        require(IERC721(nftContract).isApprovedForAll(msg.sender, address(this)) || IERC721(nftContract).getApproved(tokenId) == address(this), "Marketplace: marketplace not approved for token");

        _listingIdCounter++;
        uint256 listingId = _listingIdCounter;

        listings[listingId] = Listing({
            id: listingId,
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            price: price,
            sold: false,
            cancelled: false
        });

        _userListings[msg.sender].add(listingId);

        emit ListingCreated(listingId, msg.sender, nftContract, tokenId, price);
    }

    function cancelListing(uint256 listingId) external nonReentrant onlySeller(listingId) onlyExistingListing(listingId) {
        Listing storage listing = listings[listingId];
        require(!listing.sold, "Marketplace: listing already sold");
        require(!listing.cancelled, "Marketplace: listing already cancelled");

        listing.cancelled = true;

        _userListings[msg.sender].remove(listingId);

        emit ListingCancelled(listingId, msg.sender);
    }

    function buy(uint256 listingId) external nonReentrant onlyExistingListing(listingId) whenNotPaused {
        Listing storage listing = listings[listingId];
        require(!listing.sold, "Marketplace: listing already sold");
        require(!listing.cancelled, "Marketplace: listing cancelled");
        require(listing.seller != msg.sender, "Marketplace: seller cannot buy their own listing");

        uint256 feeAmount = (listing.price * marketplaceFee) / 10000;
        uint256 sellerAmount = listing.price - feeAmount;

        require(paymentToken.transferFrom(msg.sender, address(this), feeAmount), "Marketplace: fee transfer failed");
        require(paymentToken.transferFrom(msg.sender, listing.seller, sellerAmount), "Marketplace: payment to seller failed");

        IERC721(listing.nftContract).safeTransferFrom(listing.seller, msg.sender, listing.tokenId);

        listing.sold = true;

        _userListings[listing.seller].remove(listingId);

        emit ListingSold(listingId, msg.sender, listing.price);
    }

    function updateMarketplaceFee(uint256 newFee) external onlyRole(FEE_MANAGER_ROLE) {
        require(newFee <= 10000, "Marketplace: fee cannot exceed 100%");
        uint256 oldFee = marketplaceFee;
        marketplaceFee = newFee;

        emit MarketplaceFeeUpdated(oldFee, newFee);
    }

    function getListingsByUser(address user) external view returns (uint256[] memory) {
        uint256 count = _userListings[user].length();
        uint256[] memory userListingIds = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            userListingIds[i] = _userListings[user].at(i);
        }

        return userListingIds;
    }

    function withdrawFunds() external onlyRole(ADMIN_ROLE) {
        uint256 balance = paymentToken.balanceOf(address(this));
        require(balance > 0, "Marketplace: no funds to withdraw");
        require(paymentToken.transfer(msg.sender, balance), "Marketplace: transfer failed");
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
