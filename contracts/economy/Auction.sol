// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract Auction is ReentrancyGuard, Ownable, Pausable {
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    Counters.Counter private _auctionIds;
    Counters.Counter private _bidIds;

    enum AuctionState { Created, Active, Ended, Cancelled }

    struct AuctionItem {
        uint256 auctionId;
        address seller;
        address tokenAddress;
        uint256 tokenId;
        uint256 startingPrice;
        uint256 reservePrice;
        uint256 currentBid;
        address currentBidder;
        uint256 endTime;
        AuctionState state;
    }

    struct Bid {
        uint256 bidId;
        uint256 auctionId;
        address bidder;
        uint256 amount;
        uint256 timestamp;
    }

    mapping(uint256 => AuctionItem) public auctions;
    mapping(uint256 => Bid[]) public bids;
    mapping(address => uint256) public pendingReturns;

    event AuctionCreated(uint256 indexed auctionId, address indexed seller, uint256 tokenId, uint256 startingPrice, uint256 reservePrice, uint256 endTime);
    event AuctionCancelled(uint256 indexed auctionId);
    event AuctionEnded(uint256 indexed auctionId, address indexed winner, uint256 winningBid);
    event BidPlaced(uint256 indexed auctionId, uint256 indexed bidId, address indexed bidder, uint256 amount);
    event BidWithdrawn(uint256 indexed auctionId, address indexed bidder, uint256 amount);

    modifier auctionExists(uint256 auctionId) {
        require(auctions[auctionId].auctionId == auctionId, "Auction: auction does not exist");
        _;
    }

    modifier onlySeller(uint256 auctionId) {
        require(msg.sender == auctions[auctionId].seller, "Auction: caller is not the seller");
        _;
    }

    modifier auctionActive(uint256 auctionId) {
        require(auctions[auctionId].state == AuctionState.Active, "Auction: auction is not active");
        require(block.timestamp < auctions[auctionId].endTime, "Auction: auction has ended");
        _;
    }

    modifier auctionEnded(uint256 auctionId) {
        require(auctions[auctionId].state == AuctionState.Ended, "Auction: auction is not ended");
        require(block.timestamp >= auctions[auctionId].endTime, "Auction: auction is still ongoing");
        _;
    }

    function createAuction(
        address tokenAddress,
        uint256 tokenId,
        uint256 startingPrice,
        uint256 reservePrice,
        uint256 duration
    ) external whenNotPaused returns (uint256) {
        require(tokenAddress != address(0), "Auction: invalid token address");
        require(startingPrice > 0, "Auction: starting price must be greater than zero");
        require(duration > 0, "Auction: duration must be greater than zero");

        _auctionIds.increment();
        uint256 auctionId = _auctionIds.current();

        auctions[auctionId] = AuctionItem({
            auctionId: auctionId,
            seller: msg.sender,
            tokenAddress: tokenAddress,
            tokenId: tokenId,
            startingPrice: startingPrice,
            reservePrice: reservePrice,
            currentBid: 0,
            currentBidder: address(0),
            endTime: block.timestamp.add(duration),
            state: AuctionState.Created
        });

        auctions[auctionId].state = AuctionState.Active;

        emit AuctionCreated(auctionId, msg.sender, tokenId, startingPrice, reservePrice, auctions[auctionId].endTime);

        return auctionId;
    }

    function placeBid(uint256 auctionId) external payable nonReentrant auctionExists(auctionId) auctionActive(auctionId) {
        AuctionItem storage auction = auctions[auctionId];
        require(msg.value > auction.currentBid, "Auction: bid amount must be higher than current bid");

        if (auction.currentBidder != address(0)) {
            pendingReturns[auction.currentBidder] = pendingReturns[auction.currentBidder].add(auction.currentBid);
        }

        auction.currentBid = msg.value;
        auction.currentBidder = msg.sender;

        _bidIds.increment();
        uint256 bidId = _bidIds.current();

        bids[auctionId].push(Bid({
            bidId: bidId,
            auctionId: auctionId,
            bidder: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp
        }));

        emit BidPlaced(auctionId, bidId, msg.sender, msg.value);
    }

    function withdrawBid(uint256 auctionId) external nonReentrant auctionExists(auctionId) {
        require(pendingReturns[msg.sender] > 0, "Auction: no funds to withdraw");

        uint256 amount = pendingReturns[msg.sender];
        pendingReturns[msg.sender] = 0;

        payable(msg.sender).transfer(amount);

        emit BidWithdrawn(auctionId, msg.sender, amount);
    }

    function endAuction(uint256 auctionId) external nonReentrant auctionExists(auctionId) onlySeller(auctionId) auctionEnded(auctionId) {
        AuctionItem storage auction = auctions[auctionId];
        require(auction.currentBid >= auction.reservePrice, "Auction: reserve price not met");

        auction.state = AuctionState.Ended;

        IERC20(auction.tokenAddress).transferFrom(address(this), auction.currentBidder, auction.tokenId);
        payable(auction.seller).transfer(auction.currentBid);

        emit AuctionEnded(auctionId, auction.currentBidder, auction.currentBid);
    }

    function cancelAuction(uint256 auctionId) external nonReentrant auctionExists(auctionId) onlySeller(auctionId) {
        AuctionItem storage auction = auctions[auctionId];
        require(auction.state == AuctionState.Active, "Auction: cannot cancel inactive auction");

        auction.state = AuctionState.Cancelled;

        if (auction.currentBidder != address(0)) {
            pendingReturns[auction.currentBidder] = pendingReturns[auction.currentBidder].add(auction.currentBid);
        }

        emit AuctionCancelled(auctionId);
    }

    function getAuctionDetails(uint256 auctionId) external view auctionExists(auctionId) returns (AuctionItem memory) {
        return auctions[auctionId];
    }

    function getAuctionBids(uint256 auctionId) external view auctionExists(auctionId) returns (Bid[] memory) {
        return bids[auctionId];
    }

    function pauseAuction() external onlyOwner {
        _pause();
    }

    function unpauseAuction() external onlyOwner {
        _unpause();
    }

    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
