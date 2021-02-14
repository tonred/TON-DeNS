pragma solidity ^0.4.0;
import 'IDeNSRoot.sol';
import 'DomainBase.sol';

contract DeNSRoot is DomainBase, IDeNSRoot {
    struct Registering {
        address asd;
    }

    mapping(address => Registering[]) regMap; //address NIC contract

    function registerName(string domainShortName) public override onlyOwner returns(){
//        check is not already registered
//
    }

    function callbackRegisterName() public override onlyOwner returns(){
        //        check is not already registered

    }

    onBounce(TvmSlice body) external {
        // parse and route to callbackRegisterName
    }

}
