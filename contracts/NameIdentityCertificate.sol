pragma ton-solidity ^0.37.0;

import "DomainBase.sol";
import "interfaces/INameIdentityCertificate.sol";
import {WhoIsInfo, Records, CertificateErrors, RegistrationTypes} from "./DeNSLib.sol";
import {CertificateDeployable} from "./AbstractNameIdentityCertificate.sol";
import "ParticipantStorage.sol";


contract NameIdentityCertificate is DomainBase, INameIdentityCertificate{

    uint16 constant SEND_ALL_GAS = 128;

    uint128 constant CHECK_NIC_FEE = 0.02 ton;
    uint128 constant CHECK_NIC_VALUE = 0.1 ton;
    uint128 constant READ_PARTICIPANT_STORAGE_VALUE = 0.1 ton;
    uint128 constant DEPLOY_NIC_VALUE = 1 ton;

    address static _parent;

    string static _path;
    string static _name;


    TvmCell _participantStorageCode;

    address _owner;
    uint32 _expiresAt;
    RegistrationTypes _registrationType;
    Records _records;

    uint128 _instantBuyPrice = 10 ton;
    uint32 _instantBuyMaxSecDuration = 4 weeks;

    string[] public whs;

    event UpdateCertificate(
        address indexed previousOwner,
        address indexed newOwner,
        uint32 previousExpiresAt,
        uint32 newExpiresAt
    );
    event UpdateOwner(address indexed previousOwner, address indexed newOwner);
    event UpdateRegistrationType(RegistrationTypes previousRegistrationType, RegistrationTypes newRegistrationType);
    event UpdateRecordAddress(address previousRecordAddress, address newRecordAddress);
    event UpdateADNLAddress(string previousADNLAddress, string newADNLAddress);

    /*
     * modifiers
     */

    modifier onlyOwner {
        require(msg.sender == _owner, CertificateErrors.IS_NOT_OWNER);
        _;
    }

    modifier onlyParent {
        require(msg.sender == _parent, CertificateErrors.IS_NOT_ROOT);
        _;
    }

    modifier isAllowedRegType(RegistrationTypes registrationType) {
        require(_registrationType == registrationType, CertificateErrors.NOT_ALLOWED_REGISTRATION_TYPE);
        _;
    }


    constructor(
        uint32 expiresAt,
        RegistrationTypes registrationType,
        TvmCell certificateCode,
        TvmCell auctionCode,
        TvmCell participantStorageCode
    ) public  {
        require(msg.sender == _parent, CertificateErrors.IS_NOT_ROOT);
        tvm.accept();

        _certificateCode = certificateCode;
        _auctionCode = auctionCode;
        _participantStorageCode = participantStorageCode;

        _registrationType = registrationType;
        _expiresAt = expiresAt;

    }

    /*
     *  Getters
     */

    function getAddress() public view override returns (address){
        return _records.A;
    }

    function getAdnlAddress() public view override returns (string){
        return _records.ADNL;
    }

    function getTextRecords() public view override returns (string[]){
        return _records.TXT;
    }

    function getRecords() public view override returns (Records){
        return _records;
    }

    function getWhoIs() public view override returns (WhoIsInfo){
        return WhoIsInfo(_parent, _path, _name, _owner, _expiresAt, _records);
    }

    function getRegistrationType() public view override returns (RegistrationTypes){
        return _registrationType;
    }

    function getExpiresAt() public view override returns (uint32){
        return _expiresAt;
    }

    function getOwner() public view override returns (address){
        return _owner;
    }

    function getInstantBuyPrice() public view returns (uint128){
        return _instantBuyPrice;

    }

    function getInstantBuyMaxSecDuration() public view returns (uint32){
        return _instantBuyMaxSecDuration;
    }

    /*
    *  Public functions
    */

    function registerNameByOwner (string domainName, uint8 duration) public onlyOwner isAllowedRegType(RegistrationTypes.OwnerOnly){
        require(isNameValid(domainName), CertificateErrors.INVALID_DOMAIN_NAME);

    }

    function registerNameByAuction(string domainName, uint8 durationInYears, uint256 bidHash) public isAllowedRegType(RegistrationTypes.Auction){
        require(isNameValid(domainName), CertificateErrors.INVALID_DOMAIN_NAME);

    }

    function registerInstantName(string domainName, uint32 durationInSec) public isAllowedRegType(RegistrationTypes.Instant){
        tvm.rawReserve(address(this).balance - msg.value + CHECK_NIC_FEE + DEPLOY_NIC_VALUE, 2);
        require(msg.value >= _instantBuyPrice, CertificateErrors.NOT_ENOUGH_TOKENS_FOR_INSTANT_BUY);
        require(isNameValid(domainName), CertificateErrors.INVALID_DOMAIN_NAME);
        require(durationInSec < _instantBuyMaxSecDuration, CertificateErrors.DURATION_LARGER_MAX_ALLOWED_FOR_INSTANT_BUY);
//        require(durationInSec < _instantBuyMaxSecDuration, 111)
        uint32 requestedExpiresAt = calcRequestedExpiresAt(durationInSec);
        require(requestedExpiresAt < _expiresAt, CertificateErrors.DURATION_LARGER_ROOT_CERT_EXPIRES);

        address sender = msg.sender;
        TvmCell nicState = buildNicStateInit(domainName);
        address subdomainCertificate = address.makeAddrStd(0, tvm.hash(nicState));
        uint128 requestHash = calcRequestHash(sender, domainName);
        NameIdentityCertificate(subdomainCertificate).isAbleToRegister{value: CHECK_NIC_VALUE, callback: isAbleToRegisterCallback}(requestHash);
        TvmCell participantStorageState = buildParticipantStorageStateInit(requestHash);
        new ParticipantStorage{stateInit: participantStorageState, value: 0, flag: SEND_ALL_GAS}(sender, domainName);
    }

    function check(uint128 requestHash) private {
        TvmCell userStorage = buildParticipantStorageStateInit(requestHash);
        address pStorage = address.makeAddrStd(0, tvm.hash(userStorage));
        ParticipantStorage(pStorage).getAndDestroy{value: READ_PARTICIPANT_STORAGE_VALUE, callback: onResponse}();
    }

    function calcRequestHash(address sender, string domainName) private returns (uint128){
        TvmBuilder builder;
        builder.store(sender, domainName);
        return uint128(tvm.hash(builder.toCell()) >> 128);
    }

    function buildParticipantStorageStateInit(uint128 requestHash) private returns(TvmCell){
        return tvm.buildStateInit({
            contr: ParticipantStorage,
            varInit: {
                _root: address(this),
                _requestHash: requestHash
            },
            code: _participantStorageCode
        });
    }

    function onResponse(address sender, string domain) public {
        tvm.rawReserve(address(this).balance - msg.value, 2);
        whs.push(domain);
        sender.transfer({value: 0, flag: SEND_ALL_GAS});
    }

    onBounce(TvmSlice slice) external {
		uint32 functionId = slice.decode(uint32);
		if (functionId == tvm.functionId(isAbleToRegister)) {
            (uint32 _, uint128 requestHash) = slice.decodeFunctionParams(isAbleToRegister);
            //TODO read data from storage and deploy on callback
            deployCertificate(string("asd"), RegistrationTypes.Instant, _expiresAt - 1, DEPLOY_NIC_VALUE);
//            check(requestHash);
		}
    }

    function isAbleToRegister(uint128 requestHash) public view override returns(bool, uint128, string){
        tvm.rawReserve(address(this).balance - msg.value, 2);
        return{value: 0, flag: 128} (true, requestHash, _name);
    }

    function isAbleToRegisterCallback(bool isAvailable, uint128 requestHash, string domainName) public{
        TvmCell nicState = buildNicStateInit(domainName);
        address subdomainCertificate = address.makeAddrStd(0, tvm.hash(nicState));
        require(msg.sender == subdomainCertificate, CertificateErrors.IS_NOT_SUBDOMAIN);
        // TODO update
    }


    /*
    *  Parent functions
    */

    function updateCertificate(address newOwner, uint32 newExpiresAt) public override onlyParent {
        // TODO add checks
        address previousOwner = _owner;
        uint32 previousExpiresAt = _expiresAt;
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

    function setRegistrationType(RegistrationTypes newRegistrationType) public override onlyOwner {
        require(RegistrationTypes.OwnerOnly >= newRegistrationType, CertificateErrors.INVALID_REGISTRATION_TYPE);
        RegistrationTypes previousRegistrationType = _registrationType;
        _registrationType = newRegistrationType;
        emit UpdateRegistrationType(previousRegistrationType, newRegistrationType);
    }

    function setInstantBuyPrice(uint128 instantBuyPrice) public onlyOwner returns (uint128){
        _instantBuyPrice = instantBuyPrice;
    }

    function setInstantBuyMaxSecDuration(uint32 instantBuyMaxSecDuration) public onlyOwner returns (uint32){
        _instantBuyMaxSecDuration = instantBuyMaxSecDuration;
    }

    function setAddress(address newAddress) public override onlyOwner {
        address previousAddress = _records.A;
        _records.A = newAddress;
        emit UpdateRecordAddress(previousAddress, newAddress);
    }

    function setAdnlAddress(string newAdnlAddress) public override onlyOwner {
        string previousAddress = _records.ADNL;
        _records.ADNL = newAdnlAddress;
        emit UpdateADNLAddress(previousAddress, newAdnlAddress);
    }

    function addTextRecord(string newTextRecord) public override onlyOwner {
        return _records.TXT.push(newTextRecord);
    }

    function removeTextRecordByIndex(uint index) public override onlyOwner {
        delete _records.TXT[index];
    }

    function _setExpiresAt(uint32 newExpiresAt) private {
        _expiresAt = newExpiresAt;
    }

    function _setOwner(address newOwner) private {
        _owner = newOwner;
    }



    function calcRequestedExpiresAt(uint32 duration) private view returns(uint32){
        if (duration == 0) {
            return _expiresAt - 1;
        } else {
            return now + duration;
        }
    }

    function calcRequestedExpiresAtByYears(uint8 duration) private view returns(uint32){
        if (duration == 0) {
            return _expiresAt - 1;
        } else {
            return now + duration * 365 days;
        }
    }



    // TODO: Move to Base contract after bug with static vars will be fixed
    function getResolve(string domainName) public view override returns (address certificate){
        TvmCell state = buildNicStateInit(domainName);
        certificate = address.makeAddrStd(0, tvm.hash(state));
    }

    function getParent() public view override returns (address){
        return _parent;
    }

    function getPath() public view override returns (string){
        return _path;
    }

    function getName() public view override returns (string){
        return _name;
    }

    function buildNicStateInit(string domainName) internal view returns(TvmCell){
        string childContractPath = _path;
        if (_name.byteLength() > 0) {
            if (_path.byteLength() > 0) {
                childContractPath.append(string("/"));
            }
            childContractPath.append(_name);
        }
        return tvm.buildStateInit({
            contr: CertificateDeployable,
            varInit: {
                _parent: address(this),
                _path: childContractPath,
                _name: domainName
            },
            code: _certificateCode
        });
    }

    function deployCertificate(string domainName, RegistrationTypes registrationType, uint32 expiresAt, uint128 value) internal {
        TvmCell state = buildNicStateInit(domainName);
        new CertificateDeployable{stateInit: state, value: value}(expiresAt, registrationType, _certificateCode, _auctionCode, _participantStorageCode);
    }

}
