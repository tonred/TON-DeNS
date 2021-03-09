pragma ton-solidity ^0.37.0;

import "./interfaces/IDomainAuction.sol";
import {AuctionPhase, AuctionPhaseTime} from "./DeNSLib.sol";


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
}


contract DomainAuction is IDomainAuction {
//    uint32 constant AUCTION_CONFIRMATION_DURATION = 1 days;
    uint32 constant AUCTION_CONFIRMATION_DURATION = 30 seconds;
    uint128 constant AUCTION_DEPOSIT = 100 ton;
    uint128 constant AUCTION_FEE = 1 ton;
    uint128 constant MIN_BID_VALUE = 1 nanoton;

    address static addressNIC;
    string static relativeDomainName;
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


    constructor(uint32 thisDomainExpiresAt, uint32 auctionDuration) public {
        tvm.accept();
        domainExpiresAt = thisDomainExpiresAt;
        phase = AuctionPhase.OPEN;
        setupPhasesTime(auctionDuration);
    }

    modifier inPhase(AuctionPhase p) {
        require(phase == p, AuctionErrors.WRONG_PHASE);
        _;
    }

    modifier bidExists() {
        require(bidsHashes.exists(msg.sender), AuctionErrors.NO_SUCH_BID);
        _;
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

    function makeBid(uint256 bidHash) public override inPhase(AuctionPhase.OPEN) {
        update();
        require(!bidsHashes.exists(msg.sender), AuctionErrors.BID_ALREADY_MADE);
        require(msg.value >= AUCTION_DEPOSIT, AuctionErrors.NOT_ENOUGH_TOKENS);
        if (msg.value > AUCTION_DEPOSIT) {
            msg.sender.transfer(msg.value - AUCTION_DEPOSIT);
        }
        bidsHashes[msg.sender] = bidHash;
        bidsHashesCount++;
    }

    function removeBid() public override inPhase(AuctionPhase.OPEN) bidExists {
        update();
        tvm.accept();
        delete bidsHashes[msg.sender];
        bidsHashesCount--;
        msg.sender.transfer(AUCTION_DEPOSIT - AUCTION_FEE);
    }

    function confirmBid(uint128 bidValue, uint256 salt) public override inPhase(AuctionPhase.CONFIRMATION) bidExists {
        update();
        require(bidValue >= MIN_BID_VALUE, AuctionErrors.BID_TOO_LOW);
        require(!confirmedBids.exists(msg.sender), AuctionErrors.BID_ALREADY_CONFIRMED);
        uint256 bidHash = calcHash(bidValue, salt);
        uint256 bidHashMemo = bidsHashes[msg.sender];
        require(bidHash == bidHashMemo, AuctionErrors.CONFIRMATION_HASH_NOT_MATCH_BID_HASH);

        uint128 totalValue = msg.value + AUCTION_DEPOSIT;
        uint128 leaveValue = totalValue - bidValue - AUCTION_FEE;
        require(leaveValue >= 0, AuctionErrors.TOKEN_VALUE_LESS_THAN_BID);
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

    function updateResults(Bid bid) private {
        if (bid.value > highestBid.value) {
            secondHighestBid = highestBid;
            highestBid = bid;
        } else if (bid.value > secondHighestBid.value) {
            secondHighestBid = highestBid;
        }
    }

    function update() public override {
        if (phase == AuctionPhase.OPEN && now >= confirmationTime.startTime) {
            tvm.accept();
            phase = AuctionPhase.CONFIRMATION;
        } else if (phase == AuctionPhase.CONFIRMATION && now >= closeTime.startTime) {
            tvm.accept();
            phase = AuctionPhase.CLOSE;
            // finish();
        }
    }

    function finish() private {
        address owner = address(0);
        uint128 cost = 0;
        if (highestBid.owner == address(0)) {// todo ? check default struct value
            // no winner
            owner = address(0);
            cost = 0;
        } else if (secondHighestBid.owner == address(0)) {// todo ? check default struct value
            // one winner (one bid)
            owner = highestBid.owner;
            cost = highestBid.value;
            // todo call + send all
        } else {
            // one winner (many bids)
            owner = highestBid.owner;
            cost = secondHighestBid.value;
            // todo call + send all
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
        // todo manage money
    }

}
