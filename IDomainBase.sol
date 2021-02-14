pragma solidity ^0.4.0;

interface IDomainBase{
    string domainFullName; // tonos/asd/qwe
    string domainShortName; // qwe

    function getResolve(string domainName) external; // view public returns (optional(string));
    function getResolveByType(string domainName, string recordType) external; // view public returns (optional(string));
}
