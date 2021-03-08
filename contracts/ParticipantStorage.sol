pragma ton-solidity ^0.37.0;

struct ParticipantStoragePK{
    address account;
    string domainName;
}

struct ParticipantStorageData{
    ParticipantStoragePK pk;
    uint32 requestedExpiresAt;
}

contract ParticipantStorage {
    address static _root;
    uint128 static _requestHash;
    ParticipantStorageData _data;

    /*
    Exception codes:
    101 - message sender is not a root;
    */

    modifier onlyRoot {
        require(msg.sender == _root, 101);
        _;
    }

    constructor(ParticipantStorageData data) public onlyRoot{
        _data = data;
    }

    function getData() public view returns (ParticipantStorageData) {
        tvm.rawReserve(address(this).balance - msg.value, 2);
        return{value: 0, flag: 128} _data;
    }

    function getDataAndWithdraw(uint128 value) public view onlyRoot returns (ParticipantStorageData) {
        tvm.rawReserve(address(this).balance - msg.value - value, 2);
        return{value: 0, flag: 128} _data;
    }

    function prune() public view returns (ParticipantStoragePK) {
        return{value: 0, flag: 160} _data.pk;
    }
}
