pragma ton-solidity ^0.37.0;

import "DomainBase.sol";
import "interfaces/INameIdentityCertificate.sol";
import {WhoIsInfo, Records, CertificateErrors, RegistrationTypes} from "./DeNSLib.sol";


contract NameIdentityCertificate is DomainBase, INameIdentityCertificate{
    address static parent;

    string static absoluteDomainName;
    string static relativeDomainName;

    address owner;
    uint32 expiresAt;
    Records records;
    uint8 registrationType;

    event UpdateCertificate(address indexed previousOwner, address indexed newOwner, uint32 previousExpiresAt, uint32 newExpiresAt);
    event UpdateOwner(address indexed previousOwner, address indexed newOwner);
    event UpdateRegistrationType(uint previousRegistrationType, uint newRegistrationType);
    event UpdateRecordAddress(address previousRecordAddress, address newRecordAddress);
    event UpdateADNLAddress(string previousADNLAddress, string newADNLAddress);

    /*
     * modifiers
     */

    modifier onlyOwner {
        require(msg.sender == owner, CertificateErrors.IS_NOT_OWNER);
        _;
    }

    modifier onlyParent {
        require(msg.sender == parent, CertificateErrors.IS_NOT_ROOT);
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

    function getRegistrationType() view public override returns (uint8){
        return registrationType;
    }

    function getExpiresAt() view public override returns (uint32){
        return expiresAt;
    }

    function getOwner() view public override returns (address){
        return owner;
    }

    /*
    *  Public functions
    */


    function registerNameByOwner (string domainName, uint8 duration) public onlyOwner{
        require(registrationType == RegistrationTypes.OWNER_ONLY, CertificateErrors.REGISTRATION_BY_OWNER_NOT_ALLOWED);

    }

    function registerInstantName(string domainName, uint8 duration) public {
        require(registrationType == RegistrationTypes.INSTANT, CertificateErrors.INSTANT_REGISTRATION_NOT_ALLOWED);

    }

    function registerNameByAuction(string domainName, uint8 duration, uint256 bidHash) public {
        require(registrationType == RegistrationTypes.AUCTION, CertificateErrors.REGISTRATION_BY_AUCTION_NOT_ALLOWED);
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

    // TODO add checks for expiration

    function setOwner(address newOwner) public override onlyOwner {
        address previousOwner = newOwner;
        _setOwner(newOwner);
        emit UpdateOwner(previousOwner, newOwner);
    }

    function setRegistrationType(uint8 newRegistrationType) public override onlyOwner {
        require(newRegistrationType == RegistrationTypes.OWNER_ONLY ||
                newRegistrationType == RegistrationTypes.INSTANT ||
                newRegistrationType == RegistrationTypes.AUCTION, CertificateErrors.INVALID_REGISTRATION_TYPE);
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

   function _setExpiresAt(uint32 newExpiresAt) private {
        expiresAt = newExpiresAt;
    }

    function _setOwner(address newOwner) private {
        owner = newOwner;
    }

}
