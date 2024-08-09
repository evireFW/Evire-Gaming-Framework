// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../libraries/GameLibrary.sol";

contract StateChannel is AccessControl, ReentrancyGuard {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant CHANNEL_ADMIN_ROLE = keccak256("CHANNEL_ADMIN_ROLE");

    enum ChannelStatus { Open, Closed, Disputed }

    struct Channel {
        uint256 id;
        address[] participants;
        uint256[] balances;
        uint256 nonce;
        ChannelStatus status;
        uint256 timeout;
    }

    struct Dispute {
        uint256 channelId;
        uint256 disputedAt;
        uint256 disputeNonce;
        address challenger;
        address challenged;
    }

    uint256 private _channelCounter;
    uint256 public disputeDuration = 3 days;

    mapping(uint256 => Channel) private channels;
    mapping(uint256 => Dispute) private disputes;
    mapping(address => uint256[]) private participantChannels;

    event ChannelOpened(uint256 indexed channelId, address[] participants, uint256[] initialBalances);
    event ChannelClosed(uint256 indexed channelId, address[] finalParticipants, uint256[] finalBalances);
    event ChannelDisputed(uint256 indexed channelId, address indexed challenger, address indexed challenged, uint256 nonce);

    modifier onlyParticipant(uint256 channelId) {
        require(isParticipant(channelId, msg.sender), "Not a participant in this channel");
        _;
    }

    constructor(address admin) {
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(CHANNEL_ADMIN_ROLE, admin);
    }

    function openChannel(address[] calldata participants, uint256[] calldata initialBalances) external nonReentrant returns (uint256) {
        require(participants.length > 1, "StateChannel: Channel must have more than one participant");
        require(participants.length == initialBalances.length, "StateChannel: Participants and balances length mismatch");

        _channelCounter++;
        uint256 channelId = _channelCounter;

        channels[channelId] = Channel({
            id: channelId,
            participants: participants,
            balances: initialBalances,
            nonce: 0,
            status: ChannelStatus.Open,
            timeout: 0
        });

        for (uint256 i = 0; i < participants.length; i++) {
            participantChannels[participants[i]].push(channelId);
        }

        emit ChannelOpened(channelId, participants, initialBalances);
        return channelId;
    }

    function updateState(uint256 channelId, uint256[] calldata newBalances, uint256 newNonce) external onlyParticipant(channelId) nonReentrant {
        Channel storage channel = channels[channelId];
        require(channel.status == ChannelStatus.Open, "StateChannel: Channel is not open");
        require(newNonce > channel.nonce, "StateChannel: Nonce must be greater than the current nonce");
        require(newBalances.length == channel.balances.length, "StateChannel: Balances length mismatch");

        channel.balances = newBalances;
        channel.nonce = newNonce;
    }

    function initiateDispute(uint256 channelId, uint256 nonce) external onlyParticipant(channelId) nonReentrant {
        Channel storage channel = channels[channelId];
        require(channel.status == ChannelStatus.Open, "StateChannel: Channel is not open");
        require(nonce < channel.nonce, "StateChannel: Nonce must be less than the current nonce");

        channel.status = ChannelStatus.Disputed;
        channel.timeout = block.timestamp.add(disputeDuration);

        disputes[channelId] = Dispute({
            channelId: channelId,
            disputedAt: block.timestamp,
            disputeNonce: nonce,
            challenger: msg.sender,
            challenged: getChallengedParticipant(channelId, msg.sender)
        });

        emit ChannelDisputed(channelId, msg.sender, disputes[channelId].challenged, nonce);
    }

    function resolveDispute(uint256 channelId, uint256[] calldata finalBalances) external nonReentrant {
        Dispute storage dispute = disputes[channelId];
        require(dispute.channelId == channelId, "StateChannel: No active dispute for this channel");
        require(block.timestamp >= dispute.disputedAt.add(disputeDuration), "StateChannel: Dispute duration not yet passed");

        Channel storage channel = channels[channelId];
        channel.balances = finalBalances;
        channel.status = ChannelStatus.Closed;

        emit ChannelClosed(channelId, channel.participants, finalBalances);
    }

    function closeChannel(uint256 channelId) external onlyParticipant(channelId) nonReentrant {
        Channel storage channel = channels[channelId];
        require(channel.status == ChannelStatus.Open, "StateChannel: Channel is not open");

        channel.status = ChannelStatus.Closed;

        emit ChannelClosed(channelId, channel.participants, channel.balances);
    }

    function getChannel(uint256 channelId) external view returns (Channel memory) {
        return channels[channelId];
    }

    function getParticipantChannels(address participant) external view returns (uint256[] memory) {
        return participantChannels[participant];
    }

    function isParticipant(uint256 channelId, address participant) public view returns (bool) {
        Channel storage channel = channels[channelId];
        for (uint256 i = 0; i < channel.participants.length; i++) {
            if (channel.participants[i] == participant) {
                return true;
            }
        }
        return false;
    }

    function getChallengedParticipant(uint256 channelId, address challenger) internal view returns (address) {
        Channel storage channel = channels[channelId];
        for (uint256 i = 0; i < channel.participants.length; i++) {
            if (channel.participants[i] != challenger) {
                return channel.participants[i];
            }
        }
        revert("StateChannel: No other participants found");
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
