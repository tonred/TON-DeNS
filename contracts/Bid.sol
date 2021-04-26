pragma ton-solidity >= 0.37.0;


library BidErrors {
    uint8 constant IS_NOT_AUCTION = 101;
    uint8 constant IS_NOT_ACTIVE = 102;
}


contract Bid {
    uint8 constant SEND_ALL_GAS = 64;  // todo ?

    address static _auction;
    address static _owner;
    uint256 static _hash;
    bool _active;


    modifier onlyAuction() {
        require(msg.sender == _auction, BidErrors.IS_NOT_AUCTION);
        _;
    }

    modifier isActive() {
        require(_active, BidErrors.IS_NOT_ACTIVE);
        _;
    }

    constructor() public onlyAuction {
        _active = true;
    }

    function remove() public onlyAuction isActive returns (address, uint256) {
        _active = false;
        return {value : 0, flag : SEND_ALL_GAS, bounce: false}(_owner, _hash);
    }

    function confirm(uint128 value, uint128 msgValue) public onlyAuction isActive returns (address, uint256, uint128, uint128) {
        _active = false;
        return {value : 0, flag : SEND_ALL_GAS, bounce: false}(_owner, _hash, value, msgValue);
    }

//    function pass() public onlyAuction isActive {
//        _active = false;
//        // todo send all money to auction
//    }
}
