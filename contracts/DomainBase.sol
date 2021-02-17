pragma solidity ^0.6.0;

import "./IDomainBase.sol";

import {WhoIsInfo, Records, CertificateErrors, RegistrationTypes} from "./DeNSLib.sol";


abstract contract DomainBase is IDomainBase {
    address parent;

    string absoluteDomainName;
    string relativeDomainName;

    TvmCell certificateCode;
    TvmCell auctionCode;

    address public owner;
    uint32 public expiresAt;
    Records records;


    /*
     * modifiers
     */

    modifier onlyParent {
        require(msg.sender == parent, CertificateErrors.IS_NOT_ROOT);
        _;
    }

    modifier onlyOwner {
        require(msg.sender == owner, CertificateErrors.IS_NOT_OWNER);
        _;
    }

    modifier onlyInternalMessage {
        require(msg.sender != address(0), CertificateErrors.IS_EXT_MSG);
        _;
    }

    constructor() public onlyParent {
        tvm.accept();
    }

    /*
     *  Getters
     */

    function getParent() view public override returns (address){
        return parent;
    }

    function getAbsoluteDomainName() view public override returns (string){
        return absoluteDomainName;
    }

    function getRelativeDomainName() view public override returns (string){
        return relativeDomainName;
    }

    function getResolve(string domainName) view public override returns (address certificate){
        certificate = address(0);
    }

    function getAddress() view public override returns (address){
        return records.A;
    }

    function getAdnlAddress() view public override returns (string){
        return records.ADNL;
    }

    function getTextRecords() view public override returns (string[]){
        return records.TXT;
    }

    function getRecords() view public override returns (Records){
        return records;
    }

    function getWhoIs() view public override returns (WhoIsInfo){
        return WhoIsInfo(absoluteDomainName, parent, owner, expiresAt, records);
    }

    /*
    *  Public functions
    */

    function registerName(string domainName) public{
    }


    /*
    *  Parent functions
    */

    function updateCertificate(address newOwner, uint32 newExpiresAt) public override onlyParent {
        // TODO add checks
        owner = newOwner;
        expiresAt = newExpiresAt;
    }

    /*
    *  Owner functions
    */

    // TODO add checks for expiration

    function setOwner(address newOwner) public override onlyOwner {
        owner = newOwner;
    }

    function setRegistrationType(uint newRegistrationType)  public override onlyOwner{

    }

    function setAddress(address newAddress) public override onlyOwner {
        records.A = newAddress;
    }

    function setAdnlAddress(string newAdnlAddress) public override onlyOwner {
        records.ADNL = newAdnlAddress;
    }

    function addTextRecord(string newTextRecord) public override onlyOwner {
        return records.TXT.push(newTextRecord);
    }

    function removeTextRecordByIndex(uint index) public override onlyOwner {
        delete records.TXT[index];
    }


    /*
     *  Private functions
     */

    function splitDomain(string domainName) private returns (string, string){}

    //    onBounce(TvmSlice body) external {
    //        /*...*/
    //    }
}
