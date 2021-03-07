pragma ton-solidity ^0.37.0;

contract ParticipantStorage {
    address static _root;
    uint128 static _requestHash;
    address _account;
    string _registeredDomainName;

    /*
    Exception codes:
    100 - message sender is not a root;
    */

    constructor(address account, string registeredDomainName) public {
        require(msg.sender == _root, 100);
        tvm.accept();
        _account = account;
        _registeredDomainName = registeredDomainName;
    }

    function getAndDestroy() public returns(address, string) {
        require(msg.sender == _root, 100);
        return{value: 0, flag: 160} (_account, _registeredDomainName);
    }
}
