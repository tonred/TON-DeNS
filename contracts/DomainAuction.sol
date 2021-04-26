pragma ton-solidity >= 0.37.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "interfaces/IDomainAuction.sol";
import "interfaces/INameIdentityCertificate.sol";
import "Bid.sol";
import {AuctionPhase, AuctionPhaseTime} from "DeNSLib.sol";


struct BidData {
    address owner;
    uint128 value;
}

library AuctionErrors {
    uint8 constant IS_NOT_ROOT = 101;
    uint8 constant SMALL_FEE_VALUE = 122;
    uint8 constant SMALL_DEPOSIT_VALUE = 103;
    uint8 constant DURATION_TOO_SHORT = 104;
    uint8 constant WRONG_PHASE = 105;
    uint8 constant VALUE_LESS_THAN_DEPOSIT = 107;
    uint8 constant IS_NOT_FROM_BID = 107;
    uint8 constant NOT_ENOUGH_TOKENS = 108;
}


contract DomainAuction is IDomainAuction {
    uint8 constant SEND_ALL_GAS = 64;

    uint128 constant DEPLOY_BID_VALUE = 0.45 ton;
    uint128 constant DEFAULT_MESSAGE_VALUE = 0.45 ton;
    uint32 constant AUCTION_CONFIRMATION_DURATION = 1 days;


    address static _addressNIC;
    string static _relativeDomainName;


    uint32 _domainExpiresAt;

    uint128 _fee;
    uint128 _deposit;  // todo more than DEPLOY_BID_VALUE + DEFAULT_MESSAGE_VALUE + _fee

    AuctionPhase _phase;

    AuctionPhaseTime _openTime;
    AuctionPhaseTime _confirmationTime;
    AuctionPhaseTime _closeTime;

    TvmCell _bidCode;
    uint128 _bidsHashesCount;
    uint128 _bidsCount;

    BidData _highestBid;
    BidData _secondHighestBid;


    event HistoryRecord(
        uint32 auctionStartTime,
        uint32 auctionFinishTime,
        uint128 bidsHashesCount,
        uint128 bidsCount,
        uint128 highestBid,
        address winner,
        uint128 cost
    );


    /*************
     * MODIFIERS *
     *************/

    modifier onlyRoot() {
        require(msg.sender == _addressNIC, AuctionErrors.IS_NOT_ROOT);
        _;
    }

    modifier inPhase(AuctionPhase p) {
        require(_phase == p, AuctionErrors.WRONG_PHASE);
        _;
    }

    modifier doUpdate() {
        _update();
        _;
    }


    /***************
     * CONSTRUCTOR *
     **************/
    /*
    @param domainExpiresAt Timestamp when domain will be expired
    @param duration        Duration of auction in seconds
    @param fee             Non-returnable fee value for each bid
    @param deposit         Returnable deposit value for each bid
    @param bidCode         Code of bid contract
    */
    constructor(uint32 domainExpiresAt, uint32 duration, uint128 fee, uint128 deposit, TvmCell bidCode) public onlyRoot {
        require(fee > DEPLOY_BID_VALUE + DEFAULT_MESSAGE_VALUE, AuctionErrors.SMALL_FEE_VALUE);
        require(deposit > fee + DEPLOY_BID_VALUE + DEFAULT_MESSAGE_VALUE, AuctionErrors.SMALL_DEPOSIT_VALUE);
        require(duration > AUCTION_CONFIRMATION_DURATION, AuctionErrors.DURATION_TOO_SHORT);
        tvm.accept();
        _domainExpiresAt = domainExpiresAt;
        _fee = fee;
        _deposit = deposit;
        _bidCode = bidCode;
        _phase = AuctionPhase.OPEN;
        _setupPhasesTime(duration);
    }

    // Used only in constructor
    function _setupPhasesTime(uint32 duration) private {
        uint32 startTime = now;
        uint32 finishTime = startTime + duration;
        uint32 splitTime = finishTime - AUCTION_CONFIRMATION_DURATION;
        _openTime = AuctionPhaseTime(startTime, splitTime);
        _confirmationTime = AuctionPhaseTime(splitTime, finishTime);
        _closeTime = AuctionPhaseTime(finishTime, _domainExpiresAt);
    }


    /***********
     * GETTERS *
     **********/

    function getAddressNIC() public view override returns (address) {
        return _addressNIC;
    }

    function getRelativeDomainName() public view override returns (string) {
        return _relativeDomainName;
    }

    function getDomainExpiresAt() public view override returns (uint32) {
        return _domainExpiresAt;
    }

    function getPhase() public view override returns (AuctionPhase) {
        return _phase;
    }

    function getOpenTime() public view override returns (AuctionPhaseTime) {
        return _openTime;
    }

    function getConfirmationTime() public view override returns (AuctionPhaseTime) {
        return _confirmationTime;
    }

    function getCloseTime() public view override returns (AuctionPhaseTime) {
        return _closeTime;
    }

    function getBidsCount() public view override returns (uint128) {
        return _bidsHashesCount;
    }

    function getConfirmedBidsCount() public view override returns (uint128) {
        return _bidsCount;
    }


    /******************
     * PUBLIC METHODS *
     *****************/

    /*
    @param hash Bid hash (can be calculated via `calcBidHash` method)
    @value Must be more than deposit
    */
    function makeBid(uint256 hash) public override doUpdate inPhase(AuctionPhase.OPEN) {
        require(msg.value >= _deposit, AuctionErrors.VALUE_LESS_THAN_DEPOSIT);
        TvmCell stateInit = _buildBidStateInit(msg.sender, hash);
        new Bid{
            stateInit: stateInit,
            value: DEPLOY_BID_VALUE
        }();
        _bidsHashesCount++;
        // todo return all value except _deposit (reserve?)
    }

    /*
    @param hash Bid hash (can be calculated via `calcBidHash` method)
    @value Must be enough for all gas used in this operation
    */
    function removeBid(uint256 hash) public view override doUpdate inPhase(AuctionPhase.OPEN) {
        address bidAddress = _calcBidAddress(msg.sender, hash);
        Bid(bidAddress).remove{
            value: DEFAULT_MESSAGE_VALUE,
            callback: removeBidCallback
        }();
        return {value: 0, flag: SEND_ALL_GAS};
    }

    function removeBidCallback(address owner, uint256 hash) public {
        _checkIsBidCallback(hash);
        _bidsHashesCount--;
        owner.transfer(_deposit - _fee);
    }

    /*
    @param value Real value of bid
    @param salt  Random value that was used to calculate hash in `calcBidHash` method
    @value You must send all tokens of your bid, can be calculated as (bid_value + fee - deposit)
    */
    function confirmBid(uint128 value, uint256 salt) public view override doUpdate inPhase(AuctionPhase.CONFIRMATION) {
        require(msg.value + _deposit >= value + _fee, AuctionErrors.NOT_ENOUGH_TOKENS);
        uint256 hash = calcBidHash(value, salt);
        address bidAddress = _calcBidAddress(msg.sender, hash);
        Bid(bidAddress).confirm{
            value: DEFAULT_MESSAGE_VALUE,
            callback: confirmBidCallback
        }(value, msg.value);
    }

    function confirmBidCallback(address owner, uint256 hash, uint128 value, uint128 msgValue) public {
        _checkIsBidCallback(hash);
        _bidsCount++;
        uint128 leaveValue = msgValue + _deposit - value - _fee;
        if (leaveValue > 0) {
            msg.sender.transfer(leaveValue);
        }
        BidData bidData = BidData(owner, value);
        _updateResults(bidData);
    }

    /*
    Function to update phase of auction
    @value Must be enough for all gas used in this operation
    */
    function update() public override doUpdate {
        msg.sender.transfer({value: 0, flag: SEND_ALL_GAS, bounce: false});
    }

    /*
    Calculates hash of bid value
    Can be used off-chain before `makeBid` function
    @param value Bid value
    @param salt  Random 128-bit value (please use really random number)
    @return 256-bit hash
    */
    function calcBidHash(uint128 value, uint256 salt) public pure override returns (uint256) {
        TvmBuilder builder;
        builder.store(value, salt);
        TvmCell cell = builder.toCell();
        return tvm.hash(cell);
    }


    /********************
     * PARENT FUNCTIONS *
     *******************/

    function setInitialBid(address sender, uint256 hash) public onlyRoot {
        TvmCell stateInit = _buildBidStateInit(sender, hash);
        new Bid{
            stateInit: stateInit,
            value: DEPLOY_BID_VALUE
        }();
        _bidsHashesCount++;
    }

    function isAbleToParticipate(uint128 requestHash) public view returns (uint128, string) {
        _reserve(0);
        return{value: 0, flag: 128} (requestHash, _relativeDomainName);
    }


    /***********
     * PRIVATE *
     **********/

    function _update() private {
        if (_phase == AuctionPhase.OPEN && now >= _confirmationTime.startTime) {
            _phase = AuctionPhase.CONFIRMATION;
        }
        if (_phase == AuctionPhase.CONFIRMATION && now >= _closeTime.startTime) {
            _phase = AuctionPhase.CLOSE;
            _finish();
        }
    }

    function _checkIsBidCallback(uint256 hash) private view {
        address bidAddress = _calcBidAddress(msg.sender, hash);
        require(msg.sender == bidAddress, AuctionErrors.IS_NOT_FROM_BID);
    }

    function _calcBidAddress(address owner, uint256 hash) private view returns (address) {
        TvmCell stateInit = _buildBidStateInit(owner, hash);
        return _calcAddress(stateInit);
    }

    function _buildBidStateInit(address owner, uint256 hash) private view returns (TvmCell) {
        return tvm.buildStateInit({
            contr: Bid,
            varInit: {
                _auction: address(this),
                _owner: owner,
                _hash: hash
            },
            code: _bidCode
        });
    }

    function _calcAddress(TvmCell stateInit) private pure returns (address) {
        return address.makeAddrStd(0, tvm.hash(stateInit));
    }

    function _updateResults(BidData bidData) private {
        if (bidData.value > _highestBid.value) {
            if (_highestBid.owner != address(0)) {
                _returnBid(_highestBid);
                _secondHighestBid = _highestBid;
            }
            _highestBid = bidData;
        } else if (bidData.value > _secondHighestBid.value) {
            _returnBid(bidData);
            _secondHighestBid = bidData;
        } else {
            _returnBid(bidData);
        }
    }

    function _returnBid(BidData bidData) private pure {
        bidData.owner.transfer(bidData.value);
    }

    function _finish() private view {
        address winner = address(0);
        uint128 cost = 0;
        if (_highestBid.owner == address(0)) {
            // no winner
        } else if (_secondHighestBid.owner == address(0)) {
            // one winner (one bid)
            winner = _highestBid.owner;
            cost = _highestBid.value;
        } else {
            // one winner (many bids)
            _highestBid.owner.transfer(_highestBid.value - _secondHighestBid.value);
            winner = _highestBid.owner;
            cost = _secondHighestBid.value;
        }
        emit HistoryRecord(
            _openTime.startTime,
            _closeTime.startTime,
            _bidsHashesCount,
            _bidsCount,
            _highestBid.value,
            winner,
            cost
        );
        INameIdentityCertificate(_addressNIC).onAuctionCompletionCallback{value: 0, flag: 160}(
            _relativeDomainName,
            winner,
            _domainExpiresAt
        );
        tvm.exit();
    }

    function _reserve(uint128 additional) private view {
        tvm.rawReserve(address(this).balance - msg.value + additional, 2);
    }

}
