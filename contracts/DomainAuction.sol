pragma ton-solidity >=0.37.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "interfaces/IDomainAuction.sol";
import "interfaces/INameIdentityCertificate.sol";
import {AuctionPhase, AuctionPhaseTime} from "DeNSLib.sol";


struct Bid {
    address owner;
    uint128 value;
}

library AuctionErrors {
    uint8 constant DURATION_TOO_SHORT = 101;
    uint8 constant WRONG_PHASE = 102;
    uint8 constant NO_SUCH_BID = 103;
    uint8 constant BID_ALREADY_MADE = 104;
    uint8 constant NOT_ENOUGH_TOKENS = 105;
    uint8 constant BID_TOO_LOW = 106;
    uint8 constant BID_ALREADY_CONFIRMED = 107;
    uint8 constant CONFIRMATION_HASH_NOT_MATCH_BID_HASH = 108;
    uint8 constant TOKEN_VALUE_LESS_THAN_BID = 109;
    uint8 constant IS_NOT_ROOT = 110;
}


contract DomainAuction is IDomainAuction {
    uint16 constant SEND_ALL_GAS = 128;

    uint32 constant AUCTION_CONFIRMATION_DURATION = 1 days;
    uint128 constant AUCTION_FEE = 0.5 ton;
    uint128 constant MIN_BID_VALUE = 1 nanoton;

    address static addressNIC;
    string static relativeDomainName;

    uint128 auctionDeposit;
    uint32 domainExpiresAt;
    AuctionPhase phase;

    AuctionPhaseTime openTime;
    AuctionPhaseTime confirmationTime;
    AuctionPhaseTime closeTime;

    mapping(address => uint256) bidsHashes;
    uint64 bidsHashesCount;
    mapping(address => bool) confirmedBids;
    uint64 bidsCount;
    Bid highestBid;
    Bid secondHighestBid;

    event HistoryRecord(
        uint32 auctionStartTime,
        uint32 auctionFinishTime,
        uint32 domainExpiresAt,
        uint64 bidsHashesCount,
        uint64 bidsCount,
        uint128 highestBid,
        uint128 sellBid
    );

    /*
     * modifiers
     */

    modifier inPhase(AuctionPhase p) {
        require(phase == p, AuctionErrors.WRONG_PHASE);
        _;
    }

    modifier bidExists() {
        require(bidsHashes.exists(msg.sender), AuctionErrors.NO_SUCH_BID);
        _;
    }

    modifier onlyRoot() {
        require(msg.sender == addressNIC, AuctionErrors.IS_NOT_ROOT);
        _;
    }

    modifier update() {
        bool f = false;
        if (phase == AuctionPhase.OPEN && now >= confirmationTime.startTime && now < closeTime.startTime) {
            phase = AuctionPhase.CONFIRMATION;
            f = true;
        } else if (now >= closeTime.startTime) {
            phase = AuctionPhase.CLOSE;
            f = true;
        }
        if (f) {
            reserve(0);
            DomainAuction(address(this)).finish();
            msg.sender.transfer({value: 0, flag: SEND_ALL_GAS});
            tvm.exit();
        }
        _;
    }

    constructor(uint32 thisDomainExpiresAt, uint32 auctionDuration, uint128 auctionDeposit_) public onlyRoot {
        domainExpiresAt = thisDomainExpiresAt;
        auctionDeposit = auctionDeposit_;
        phase = AuctionPhase.OPEN;
        setupPhasesTime(auctionDuration);
    }

    /*
     *  Getters
     */

    function getAddressNIC() public view override returns (address) {
        return addressNIC;
    }

    function getRelativeDomainName() public view override returns (string) {
        return relativeDomainName;
    }

    function getDomainExpiresAt() public view override returns (uint32) {
        return domainExpiresAt;
    }

    function getPhase() public view override returns (AuctionPhase) {
        return phase;
    }

    function getOpenTime() public view override returns (AuctionPhaseTime) {
        return openTime;
    }

    function getConfirmationTime() public view override returns (AuctionPhaseTime) {
        return confirmationTime;
    }

    function getCloseTime() public view override returns (AuctionPhaseTime) {
        return closeTime;
    }

    function getCurrentBidsCount() public view override returns (uint64) {
        return bidsHashesCount;
    }

    function getBid(address bidder) public view override returns (uint256) {
        return bidsHashes[bidder];
    }

    /*
    *  Public functions
    */

    function makeBid(uint256 bidHash) public override update inPhase(AuctionPhase.OPEN) {
        require(!bidsHashes.exists(msg.sender), AuctionErrors.BID_ALREADY_MADE);
        require(msg.value >= auctionDeposit, AuctionErrors.NOT_ENOUGH_TOKENS);
        if (msg.value > auctionDeposit) {
            msg.sender.transfer(msg.value - auctionDeposit);
        }
        bidsHashes[msg.sender] = bidHash;
        bidsHashesCount++;
    }

    function removeBid() public override update inPhase(AuctionPhase.OPEN) bidExists {
        delete bidsHashes[msg.sender];
        bidsHashesCount--;
        msg.sender.transfer(auctionDeposit - AUCTION_FEE);
    }

    function confirmBid(uint128 bidValue, uint256 salt) public override update inPhase(AuctionPhase.CONFIRMATION) bidExists {
        require(bidValue >= MIN_BID_VALUE, AuctionErrors.BID_TOO_LOW);
        require(!confirmedBids.exists(msg.sender), AuctionErrors.BID_ALREADY_CONFIRMED);
        uint256 bidHash = calcHash(bidValue, salt);
        uint256 bidHashMemo = bidsHashes[msg.sender];
        require(bidHash == bidHashMemo, AuctionErrors.CONFIRMATION_HASH_NOT_MATCH_BID_HASH);
        uint128 totalValue = msg.value + auctionDeposit - AUCTION_FEE;
        require(bidValue > totalValue, AuctionErrors.TOKEN_VALUE_LESS_THAN_BID);
        uint128 leaveValue = totalValue - bidValue;
        if (leaveValue > 0) {
            msg.sender.transfer(leaveValue);
        }
        confirmedBids[msg.sender] = true;
        bidsCount++;
        Bid bid = Bid(msg.sender, bidValue);
        updateResults(bid);
    }

    function calcHash(uint128 bidValue, uint256 salt) public pure override returns (uint256) {
        TvmBuilder builder;
        builder.store(bidValue, salt);
        TvmCell cell = builder.toCell();
        return tvm.hash(cell);
    }

    /* Self call functions */

    function finish() public view {
        require(msg.sender == address(this), 100);
        tvm.accept();
        _finish();
    }

    /*
     *  Parent functions
     */

    function setInitialBid(address sender, uint256 bidHash) public onlyRoot {
        bidsHashes[sender] = bidHash;
        bidsHashesCount++;
    }

    function isAbleToParticipate(uint128 requestHash) public view returns (uint128, string) {
        reserve(0);
        return{value: 0, flag: 128} (requestHash, relativeDomainName);
    }

    /*
     *  Private functions
     */

    function updateResults(Bid bid) private {
        if (bid.value > highestBid.value) {
            if (highestBid.owner != address(0)) {
                returnBid(highestBid);
                secondHighestBid = highestBid;
            }
            highestBid = bid;
        } else if (bid.value > secondHighestBid.value) {
            returnBid(bid);
            secondHighestBid = bid;
        } else {
            returnBid(bid);
        }
    }

    function returnBid(Bid bid) private pure {
        bid.owner.transfer(bid.value);
    }

    function _finish() private view {
        address winner = address(0);
        uint128 cost = 0;
        if (highestBid.owner == address(0)) {
            // no winner
        } else if (secondHighestBid.owner == address(0)) {
            // one winner (one bid)
            winner = highestBid.owner;
            cost = highestBid.value;
        } else {
            // one winner (many bids)
            highestBid.owner.transfer(highestBid.value - secondHighestBid.value);
            winner = highestBid.owner;
            cost = secondHighestBid.value;
        }
        emit HistoryRecord(
            openTime.startTime,
            closeTime.startTime,
            domainExpiresAt,
            bidsHashesCount,
            bidsCount,
            highestBid.value,
            cost
        );
        INameIdentityCertificate(addressNIC).onAuctionCompletionCallback{value: 0, flag: 160}(
            relativeDomainName,
            winner,
            domainExpiresAt
        );
    }

    function setupPhasesTime(uint32 auctionDuration) private {
        require(auctionDuration > AUCTION_CONFIRMATION_DURATION, AuctionErrors.DURATION_TOO_SHORT);
        uint32 startTime = now;
        uint32 finishTime = startTime + auctionDuration;
        uint32 splitTime = finishTime - AUCTION_CONFIRMATION_DURATION;
        openTime = AuctionPhaseTime(startTime, splitTime);
        confirmationTime = AuctionPhaseTime(splitTime, finishTime);
        closeTime = AuctionPhaseTime(finishTime, domainExpiresAt);
    }

    function reserve(uint128 additional) private view {
        tvm.rawReserve(address(this).balance - msg.value + additional, 2);
    }


}
