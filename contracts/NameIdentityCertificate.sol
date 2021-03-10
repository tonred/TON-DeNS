pragma ton-solidity >=0.37.0;

import "DomainBase.sol";
import "interfaces/INameIdentityCertificate.sol";
import {WhoIsInfo, Records, DeNsErrors, RegistrationTypes} from "./DeNSLib.sol";
import {CertificateDeployable} from "./AbstractNameIdentityCertificate.sol";
import "ParticipantStorage.sol";


contract NameIdentityCertificate is DomainBase, INameIdentityCertificate{

    uint16 constant SEND_ALL_GAS = 128;

    uint128 constant CHECK_NIC_FEE = 0.03 ton;
    uint128 constant DEFAULT_MESSAGE_VALUE = 0.1 ton;
    uint128 constant DEPLOY_NIC_VALUE = 1 ton;

    address static _parent;

    string static _path;
    string static _name;

    uint128 _startBalance;

    TvmCell _participantStorageCode;

    address _owner;
    uint32 _expiresAt;
    RegistrationTypes _registrationType;
    Records _records;

    uint128 _instantBuyPrice = 10 ton;
    uint32 _instantBuyMaxSecDuration = 4 weeks;

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
        require(msg.sender == _owner, DeNsErrors.IS_NOT_OWNER);
        _;
    }

    modifier onlyParent {
        require(msg.sender == _parent, DeNsErrors.IS_NOT_ROOT);
        _;
    }

    modifier isAllowedRegType(RegistrationTypes registrationType) {
        require(_registrationType == registrationType, DeNsErrors.NOT_ALLOWED_REGISTRATION_TYPE);
        _;
    }


    constructor(
        address owner,
        uint32 expiresAt,
        RegistrationTypes registrationType,
        TvmCell certificateCode,
        TvmCell auctionCode,
        TvmCell participantStorageCode
    ) public onlyParent{

        _certificateCode = certificateCode;
        _auctionCode = auctionCode;
        _participantStorageCode = participantStorageCode;

        _owner = owner;
        _registrationType = registrationType;
        _expiresAt = expiresAt;

        _startBalance = msg.value;

    }

    /*
     *  Getters
     */

    function getAddress() public view override returns (address) {
        return _records.A;
    }

    function getAdnlAddress() public view override returns (string) {
        return _records.ADNL;
    }

    function getTextRecords() public view override returns (string[]) {
        return _records.TXT;
    }

    function getRecords() public view override returns (Records) {
        return _records;
    }

    function getWhoIs() public view override returns (WhoIsInfo) {
        return WhoIsInfo(_parent, _path, _name, _owner, _expiresAt, _records);
    }

    function getRegistrationType() public view override returns (RegistrationTypes) {
        return _registrationType;
    }

    function getExpiresAt() public view override returns (uint32) {
        return _expiresAt;
    }

    function getOwner() public view override returns (address) {
        return _owner;
    }

    function getInstantBuyPrice() public view override returns (uint128) {
        return _instantBuyPrice;
    }

    function getInstantBuyMaxSecDuration() public view override returns (uint32) {
        return _instantBuyMaxSecDuration;
    }

    /*
    *  Public functions
    */

    /* Register New Name */

    function registerNameByOwner (
        string domainName,
        uint8 duration
    ) public override onlyOwner isAllowedRegType(RegistrationTypes.OwnerOnly) {
        require(isNameValid(domainName), DeNsErrors.INVALID_DOMAIN_NAME);

    }

    function registerNameByAuction(
        string domainName,
        uint8 durationInYears,
        uint256 bidHash
    ) public override isAllowedRegType(RegistrationTypes.Auction) {
        require(isNameValid(domainName), DeNsErrors.INVALID_DOMAIN_NAME);

    }

    function registerInstantName(
        string domainName,
        uint32 durationInSec
    ) public override isAllowedRegType(RegistrationTypes.Instant) {
        require(msg.value >= _instantBuyPrice, DeNsErrors.NOT_ENOUGH_TOKENS_FOR_INSTANT_BUY);
        require(isNameValid(domainName), DeNsErrors.INVALID_DOMAIN_NAME);
        require(durationInSec < _instantBuyMaxSecDuration, DeNsErrors.DURATION_LARGER_MAX_ALLOWED_FOR_INSTANT_BUY);
        uint32 requestedExpiresAt = calcRequestedExpiresAt(durationInSec);
        require(requestedExpiresAt < _expiresAt, DeNsErrors.DURATION_LARGER_ROOT_CERT_EXPIRES);

        tvm.rawReserve(address(this).balance - msg.value + CHECK_NIC_FEE, 2);

        address sender = msg.sender;
        TvmCell nicState = buildNicStateInit(domainName);
        address subdomainCertificate = address.makeAddrStd(0, tvm.hash(nicState));

        ParticipantStoragePK storagePk = ParticipantStoragePK(sender, domainName);
        uint128 requestHash = calcRequestHash(storagePk);

        NameIdentityCertificate(subdomainCertificate).isAbleToRegister{
            value: DEFAULT_MESSAGE_VALUE,
            callback: isAbleToRegisterCallback
        }(requestHash);
        TvmCell participantStorageState = buildParticipantStorageStateInit(address(this), requestHash);
        ParticipantStorageData pStorageData = ParticipantStorageData(storagePk, requestedExpiresAt);

        new ParticipantStorage{stateInit: participantStorageState, value: 0, flag: SEND_ALL_GAS}(pStorageData);
    }

    /*
    *  Callbacks
    */

    /* work with subdomain callbacks*/

    function onUpdateChildCert(string domain, address sender, bool successful) public view {
        checkIsMessageFromSubdomain(domain);
        uint128 requestHash = calcRequestHash(ParticipantStoragePK(sender, domain));
        address pStorage = calcParticipantStorageAddress(requestHash);
        if (successful) {
            ParticipantStorage(pStorage).prune{
                value: DEFAULT_MESSAGE_VALUE,
                callback: onStoragePrunePayToOwner
            }();
        }
        else {
            ParticipantStorage(pStorage).prune{
                value: DEFAULT_MESSAGE_VALUE,
                callback: onStoragePruneReturnFunds
            }();
        }
    }

    function isAbleToRegisterCallback(bool isAvailable, uint128 requestHash, string domainName) public view {
        checkIsMessageFromSubdomain(domainName);
        if (!isAvailable) {
            address pStorage = calcParticipantStorageAddress(requestHash);
            ParticipantStorage(pStorage).prune{value: DEFAULT_MESSAGE_VALUE, callback: onStoragePruneReturnFunds}();
        }
        // TODO update
    }

    onBounce(TvmSlice slice) external view {
        uint32 functionId = slice.decode(uint32);
        if (functionId == tvm.functionId(isAbleToRegister)) {
            (uint32 _, uint128 requestHash) = slice.decodeFunctionParams(isAbleToRegister);
            address pStorage = calcParticipantStorageAddress(requestHash);
            ParticipantStorage(pStorage).getDataAndWithdraw{
                value: DEFAULT_MESSAGE_VALUE,
                callback: onStorageReadResponse
            }(DEPLOY_NIC_VALUE + DEFAULT_MESSAGE_VALUE);
        } else if (functionId == tvm.functionId(updateCertificate)){
            // TODO return funds
        }
    }


    /* storage read callbacks */

    function onStoragePrunePayToOwner(ParticipantStoragePK storageDataPK) public view {
        uint128 requestHash = calcRequestHash(storageDataPK);
        checkIsMessageFromStorage(requestHash);
        tvm.rawReserve(_startBalance, 2);
        _owner.transfer({value: 0, flag: SEND_ALL_GAS, bounce: false});
    }

    function onStoragePruneReturnFunds(ParticipantStoragePK storageDataPK) public view {
        uint128 requestHash = calcRequestHash(storageDataPK);
        checkIsMessageFromStorage(requestHash);
        tvm.rawReserve(math.max(_startBalance, address(this).balance - msg.value), 2);
        storageDataPK.account.transfer({value: 0, flag: SEND_ALL_GAS, bounce: false});
    }

    function onStorageReadResponse(ParticipantStorageData storageData) public {
        uint128 requestHash = calcRequestHash(storageData.pk);
        checkIsMessageFromStorage(requestHash);
        address cert = deployCertificate(storageData.pk.domainName, RegistrationTypes.Instant, 0, DEPLOY_NIC_VALUE);
        NameIdentityCertificate(cert).updateCertificate{
            value: DEFAULT_MESSAGE_VALUE ,
            callback: onUpdateChildCert
        }(storageData.pk.account, storageData.requestedExpiresAt);
    }

    function isAbleToRegister(uint128 requestHash) public view override returns (bool, uint128, string) {
        tvm.rawReserve(address(this).balance - msg.value, 2);
        // todo is able?
        return{value: 0, flag: SEND_ALL_GAS} (false, requestHash, _name);
    }

    /*
    *  Parent functions
    */

    function updateCertificate(
        address newOwner,
        uint32 newExpiresAt
    ) public override onlyParent returns (string, address, bool) {
        // TODO add checks
        if (false){
//        require(_expiresAt == 0, 111);
            return{value: 0, flag: SEND_ALL_GAS} (_name, newOwner, false);
        }
        tvm.rawReserve(address(this).balance - msg.value, 2);
        address previousOwner = _owner;
        uint32 previousExpiresAt = _expiresAt;
        _setOwner(newOwner);
        _setExpiresAt(newExpiresAt);
        emit UpdateCertificate(previousOwner, newOwner, previousExpiresAt, newExpiresAt);
        return{value: 0, flag: SEND_ALL_GAS} (_name, newOwner, true);
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
        require(RegistrationTypes.OwnerOnly >= newRegistrationType, DeNsErrors.INVALID_REGISTRATION_TYPE);
        RegistrationTypes previousRegistrationType = _registrationType;
        _registrationType = newRegistrationType;
        emit UpdateRegistrationType(previousRegistrationType, newRegistrationType);
    }

    function setInstantBuyPrice(uint128 instantBuyPrice) public onlyOwner returns (uint128) {
        _instantBuyPrice = instantBuyPrice;
    }

    function setInstantBuyMaxSecDuration(uint32 instantBuyMaxSecDuration) public onlyOwner returns (uint32) {
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

    /*
     *  Private functions
     */

    /*  Storage helper functions */

    function calcRequestHash(ParticipantStoragePK pk) private pure returns (uint128) {
        TvmBuilder builder;
        builder.store(pk);
        return uint128(tvm.hash(builder.toCell()) >> 128);
    }

    function checkIsMessageFromStorage(uint128 requestHash) private view {
        address pStorage = calcParticipantStorageAddress(requestHash);
        require(msg.sender == pStorage, DeNsErrors.IS_NOT_STORAGE);
    }

    function calcParticipantStorageAddress(uint128 requestHash) private view returns (address) {
        TvmCell storageState = buildParticipantStorageStateInit(address(this), requestHash);
        return address.makeAddrStd(0, tvm.hash(storageState));
    }

    function buildParticipantStorageStateInit(address root, uint128 requestHash) private view returns (TvmCell) {
        return tvm.buildStateInit({
            contr: ParticipantStorage,
            varInit: {
                _root: root,
                _requestHash: requestHash
            },
            code: _participantStorageCode
        });
    }

    /*  subdomain helper functions */

    function checkIsMessageFromSubdomain(string domainName) private view {
         address subdomainCertificate = getResolve(domainName);
         require(msg.sender == subdomainCertificate, DeNsErrors.IS_NOT_SUBDOMAIN);
    }

    function calcRequestedExpiresAt(uint32 duration) private view returns (uint32) {
        if (duration == 0) {
            return _expiresAt - 1;
        } else {
            return now + duration;
        }
    }

    function calcRequestedExpiresAtByYears(uint8 duration) private view returns (uint32) {
        if (duration == 0) {
            return _expiresAt - 1;
        } else {
            return now + duration * 365 days;
        }
    }



    // TODO: Move to Base contract after bug with static vars will be fixed in SOLC
    function getResolve(string domainName) public view override returns (address certificate) {
        TvmCell state = buildNicStateInit(domainName);
        certificate = address.makeAddrStd(0, tvm.hash(state));
    }

    function getParent() public view override returns (address) {
        return _parent;
    }

    function getPath() public view override returns (string) {
        return _path;
    }

    function getName() public view override returns (string) {
        return _name;
    }

    function buildNicStateInit(string domainName) internal view returns (TvmCell) {
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

    function deployCertificate(
        address owner,
        string domainName,
        RegistrationTypes registrationType,
        uint32 expiresAt,
        uint128 value
    ) internal returns (address) {
        TvmCell state = buildNicStateInit(domainName);
        return new CertificateDeployable{
            stateInit: state,
            value: value
        }(owner, expiresAt, registrationType, _certificateCode, _auctionCode, _participantStorageCode);
    }
}
