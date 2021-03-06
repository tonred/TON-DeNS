pragma ton-solidity ^0.37.0;

import "./interfaces/IDomainAuction.sol";


enum Phase {OPEN, CONFIRMATION, CLOSE}

struct PhaseTime {
    uint32 startTime;
    uint32 finishTime;
}

//    struct HistoryRecord {
//        uint32 auctionStartTime;
//        uint32 auctionFinishTime;
//        uint32 domainExpiresAt;
//        uint64 bidsHashesCount;
//        uint64 bidsCount;
//        ufixed confirmationPercent; // ? todo ?
//        uint128 highestBid;
//        uint128 sellBid;
//        ufixed pricePerDay;
//    }

struct Bid {
    address owner;
    uint128 value;
}

library AuctionErrors {
    uint constant NOT_ENOUGH_TOKENS_FOR_BID = 101;
    uint constant BID_ALREADY_MADE = 101;
    uint constant NO_BID_TO_REMOVE = 101;
    uint constant CANNOT_CONFIRM_BID_IN_CONFIRMATION_PHASE = 101;
    uint constant CANNOT_CONFIRM_BID_IN_CLOSE_PHASE = 101;
    uint constant CANNOT_REMOVE_BID_IN_CONFIRMATION_PHASE = 101;
    uint constant BID_TOO_LOW = 101;
    uint constant CANNOT_MAKE_BID_IN_CONFIRMATION_PHASE = 101;
    uint constant NO_BID_TO_CONFIRM = 101;
    uint constant BID_ALREADY_CONFIRMED = 101;
    uint constant CONFIRMATION_HASH_NOT_MATCH_BID_HASH = 101;  // mismatch
    uint constant TOKEN_VALUE_LESS_THAN_BID = 101;
}

contract Auction is IDomainAuction {
//    uint32 constant AUCTION_CONFIRMATION_DURATION = 1 days;
    uint32 constant AUCTION_CONFIRMATION_DURATION = 30 seconds;
    uint128 constant AUCTION_DEPOSIT = 100 ton;
    uint128 constant AUCTION_FEE = 1 ton;
    uint128 constant MIN_BID_VALUE = 1 nanoton;

    address static addressNIC;
    string static relativeDomainName;
    uint32 domainExpiresAt;
    Phase phase;
    PhaseTime openTime;
    PhaseTime confirmationTime;
    PhaseTime closeTime;
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
        phase = Phase.OPEN;
        setupPhasesTime(auctionDuration);
    }

    function setupPhasesTime(uint32 auctionDuration) private {
        // todo duration more than AUCTION_CONFIRMATION_DURATION
        uint32 startTime = now;
        uint32 finishTime = startTime + auctionDuration;
        uint32 splitTime = finishTime - AUCTION_CONFIRMATION_DURATION;
        openTime = PhaseTime(startTime, splitTime);
        confirmationTime = PhaseTime(splitTime, finishTime);
        closeTime = PhaseTime(finishTime, domainExpiresAt);
    }

    function getAddressNIC() external view returns (address) {
        return addressNIC;
    }

    function getRelativeDomainName() external view returns (string) {
        return relativeDomainName;
    }

    function getDomainExpiresAt() external view returns (uint32) {
        return domainExpiresAt;
    }

    function getPhase() external returns (Phase) {
        update();
        return phase;
    }

    function getOpenTime() external view returns (PhaseTime) {
        return openTime;
    }

    function getConfirmationTime() external view returns (PhaseTime) {
        return confirmationTime;
    }

    function getCloseTime() external view returns (PhaseTime) {
        return closeTime;
    }

    function getCurrentBidsCount() external view returns (uint64) {
        return bidsHashesCount;
    }

    function makeBid(uint256 bidHash) external public {
        update();
        require(phase != Phase.CONFIRMATION, AuctionErrors.CANNOT_MAKE_BID_IN_CONFIRMATION_PHASE);
        require(phase != Phase.CLOSE, AuctionErrors.CANNOT_MAKE_BID_IN_CONFIRMATION_PHASE);
        require(!bidsHashes.exists(msg.sender), AuctionErrors.BID_ALREADY_MADE);
        require(msg.value >= AUCTION_DEPOSIT, AuctionErrors.NOT_ENOUGH_TOKENS_FOR_BID);
        if (msg.value > AUCTION_DEPOSIT) {
            msg.sender.transfer(msg.value - AUCTION_DEPOSIT);
        }
        bidsHashes[msg.sender] = bidHash;
        bidsHashesCount++;
    }

    function removeBid() external public {
        update();
        require(phase != Phase.CONFIRMATION, AuctionErrors.CANNOT_REMOVE_BID_IN_CONFIRMATION_PHASE);
        require(phase != Phase.CLOSE, AuctionErrors.CANNOT_REMOVE_BID_IN_CONFIRMATION_PHASE);
        require(bidsHashes.exists(msg.sender), AuctionErrors.NO_BID_TO_REMOVE);
        tvm.accept();
        delete bidsHashes[msg.sender];
        bidsHashesCount--;
        msg.sender.transfer(AUCTION_DEPOSIT - AUCTION_FEE);
    }

    function confirmBid(uint128 bidValue, uint256 salt) external public {
        update();
        require(phase != Phase.OPEN, AuctionErrors.CANNOT_CONFIRM_BID_IN_CONFIRMATION_PHASE);
        require(phase != Phase.CLOSE, AuctionErrors.CANNOT_CONFIRM_BID_IN_CLOSE_PHASE);
        require(bidValue >= MIN_BID_VALUE, AuctionErrors.BID_TOO_LOW);
        require(bidsHashes.exists(msg.sender), AuctionErrors.NO_BID_TO_CONFIRM);
        require(!confirmedBids.exists(msg.sender), AuctionErrors.BID_ALREADY_CONFIRMED);
        uint256 bidHash = hash(bidValue, salt);
        uint256 bidHashMemo = bidsHashes[msg.sender];
        require(bidHash == bidHashMemo, AuctionErrors.CONFIRMATION_HASH_NOT_MATCH_BID_HASH);
        tvm.accept();
        // todo really ?
        uint128 totalValue = msg.value + AUCTION_DEPOSIT;
        uint128 leaveValue = totalValue - bidValue - AUCTION_FEE;
        require(leaveValue >= 0, AuctionErrors.TOKEN_VALUE_LESS_THAN_BID);
        if (leaveValue < 0) {
            msg.sender.transfer(0, false, 64);
            return;
            // todo return ?!?!?!?!?!?!
        } else if (leaveValue > 0) {
            msg.sender.transfer(leaveValue);
        }
        confirmedBids[msg.sender] = true;
        bidsCount++;
        Bid bid = Bid(msg.sender, bidValue);
        updateResults(bid);
    }

    function hash(uint128 bidValue, uint256 salt) pure private returns (uint256) {
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

    function update() external public {
        if (phase == Phase.OPEN && now >= confirmationTime.startTime) {
            tvm.accept();
            phase = Phase.CONFIRMATION;
        } else if (phase == Phase.CONFIRMATION && now >= closeTime.startTime) {
            tvm.accept();
            phase = Phase.CLOSE;
            finish();
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
        } else {
            // one winner (many bids)
            owner = highestBid.owner;
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
        // todo manage money
    }

    function test() public pure returns (bool) {
        return true;
    }

}
