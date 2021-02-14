pragma solidity ^0.4.0;

import "./IDomainBase.sol";
import "./DeNSLib.sol";


contract DomainBase is IDomainBase{
    address owner;
    modifier onlyOwner {
        require(msg.sender == owner, Errors.IS_NOT_OWNER);
        _;
    }

    modifier onlyInternalMessage {
        require(msg.sender != address(0), Errors.IS_EXT_MSG);
        _;
    }

    function getResolve(string domainName) view public returns (optional(string));
    function getResolveByType(string domainName, string recordType) view public returns (optional(string));

    function registerName(string domainName) public returns();

    function splitDomain(string domainName) private returns (string, string);
}
