pragma solidity ^0.6.0;

import "interfaces/IDomainBase.sol";

import {WhoIsInfo, Records, CertificateErrors, RegistrationTypes} from "./DeNSLib.sol";


abstract contract DomainBase is IDomainBase {
    address parent;

    string absoluteDomainName;
    string relativeDomainName;

    TvmCell certificateCode;
    TvmCell auctionCode;

    address owner;
    uint32 expiresAt;
    Records records;

    uint registrationType;

    /*
     * events 🤗
     */

    event UpdateCertificate(address indexed previousOwner, address indexed newOwner, uint32 previousExpiresAt, uint32 newExpiresAt);
    event UpdateOwner(address indexed previousOwner, address indexed newOwner);
    event UpdateRegistrationType(uint previousRegistrationType, uint newRegistrationType);
    event UpdateRecordAddress(uint previousRecordAddress, uint newRecordAddress);
    event UpdateADNLAddress(uint previousADNLAddress, uint newADNLAddress);

    event RegistrationNameByOwner();
    event RegistrationInstantName();
    event RegistrationNameByAuction();

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

//    onBounce(TvmSlice body) external {
//        /*...*/
//    }

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

    function getRegistrationType() view public override returns (uint){
        return registrationType;
    }

    function getOwner() view public override returns (address){
        return owner;
    }

    function getExpiresAt() view public override returns (uint32){
        return expiresAt;
    }

    function getCertificateCode() view public override returns (TvmCell){
        return certificateCode;
    }

    function getAuctionCode() view public override returns (TvmCell){
        return auctionCode;
    }

    /*
    *  Public functions
    */

    function registerNameByOwner (string domainName, uint8 duration) public onlyOwner{
        require(registrationType == RegistrationTypes.OWNER_ONLY, CertificateErrors.REGISTRATION_BY_OWNER_NOT_ALLOWED);
        emit RegistrationNameByOwner();
    }

    function registerInstantName(string domainName, uint8 duration) public {
        require(registrationType == RegistrationTypes.INSTANT, CertificateErrors.INSTANT_REGISTRATION_NOT_ALLOWED);
        emit RegistrationInstantName();
    }

    function registerNameByAuction(string domainName, uint8 duration, uint256 bidHash) public {
        require(registrationType == RegistrationTypes.AUCTION, CertificateErrors.REGISTRATION_BY_AUCTION_NOT_ALLOWED);
        emit RegistrationNameByAuction();
    }


    function checkDomainCallback() public {
        //TODO check where from message

    }

    /*
    *  Parent functions
    */

    function updateCertificate(address newOwner, uint32 newExpiresAt) public override onlyParent {
        // TODO add checks
        address previousOwner = owner;
        uint32 previousExpiresAt = expiresAt;
        _setOwner(newOwner);
        _setExpiresAt(newExpiresAt);
        emit UpdateCertificate(previousOwner, newOwner, previousExpiresAt, newExpiresAt);
    }

    /*
    *  Owner functions
    */

    function setOwner(address newOwner) public override onlyOwner {
        address previousOwner = newOwner;
        _setOwner(newOwner);
        emit UpdateOwner(previousOwner, newOwner);
    }

    // TODO add checks for expiration

    function setRegistrationType(uint newRegistrationType) public override onlyOwner {
        uint previousRegistrationType = registrationType;
        registrationType = newRegistrationType;
        emit UpdateRegistrationType(previousRegistrationType, newRegistrationType);
    }

    function setAddress(address newAddress) public override onlyOwner {
        address previousAddress = records.A;
        records.A = newAddress;
        emit UpdateRecordAddress(previousAddress, newAddress);
    }

    function setAdnlAddress(string newAdnlAddress) public override onlyOwner {
        string previousAddress = records.ADNL;
        records.ADNL = newAdnlAddress;
        emit UpdateADNLAddress(previousAddress, newAdnlAddress);
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

    function _setExpiresAt(uint32 newExpiresAt) private {
        expiresAt = newExpiresAt;
    }

    function _setOwner(address newOwner) private {
        owner = newOwner;
    }
}
