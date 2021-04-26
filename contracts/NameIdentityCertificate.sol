pragma ton-solidity >=0.37.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;
import "DomainBase.sol";
import "interfaces/INameIdentityCertificate.sol";
import {WhoIsInfo, Records, DeNsErrors, RegistrationTypes} from "DeNSLib.sol";
import {CertificateDeployable} from "AbstractNameIdentityCertificate.sol";
import "ParticipantStorage.sol";
import "DomainAuction.sol";


contract NameIdentityCertificate is DomainBase, INameIdentityCertificate {
    uint32 constant REGISTRATION_PERIOD = 28 days;

    uint128 constant DEFAULT_MESSAGE_VALUE = 0.5 ton;
    uint128 constant DEPLOY_NIC_VALUE = 1 ton;
    uint128 constant DEPLOY_AUCTION_VALUE = 1 ton;

    address static _parent;

    string static _path;
    string static _name;

    uint128 _startBalance;

    address _owner;
    uint32 _expiresAt;
    RegistrationTypes _registrationType;
    Records _records;

    uint128 _auctionFee = 1 ton;
    uint128 _auctionDeposit = 10 ton;
    uint128 _instantBuyPrice = 10 ton;
    uint32 _instantBuyMaxSecDuration = 4 weeks;

    event UpdateCertificate(address newOwner, uint32 newExpiresAt);
    event UpdateOwner(address newOwner);
    event UpdateRegistrationType(RegistrationTypes newRegistrationType);
    event UpdateRecordAddress(address newRecordAddress);
    event UpdateADNLAddress(string newADNLAddress);
    event CertificateDeployed(string name);
    event AuctionDeployed(string name);

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

    modifier update() {
        if(isExpired()) {
            reserve(0);
            _owner = address(0);
            string[] TXT;
            _records = Records(address(0), string(""), TXT);
            msg.sender.transfer({value: 0, flag: SEND_ALL_GAS});
            tvm.exit();
        }
        _;
    }

    constructor(
        address owner,
        uint32 expiresAt,
        RegistrationTypes registrationType,
        TvmCell certificateCode,
        TvmCell auctionCode,
        TvmCell bidCode,
        TvmCell participantStorageCode
    ) public onlyParent{

        _certificateCode = certificateCode;
        _auctionCode = auctionCode;
        _bidCode = bidCode;
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

    function getResolveAuction(string domainName) public view returns (address){
        TvmCell auctionStateInit = buildAuctionStateInit(domainName);
        return calcAddress(auctionStateInit);
    }

    /*
    *  Public functions
    */

    /* Register New Name */

    function registerNameByOwner (
        string domainName,
        uint32 expiresAt
    ) public override update onlyOwner isAllowedRegType(RegistrationTypes.OwnerOnly) {
        require(isNameValid(domainName), DeNsErrors.INVALID_DOMAIN_NAME);
        require(expiresAt < _expiresAt, DeNsErrors.DURATION_LARGER_ROOT_CERT_EXPIRES);
        reserve(0);
        deployCertificate(_owner, domainName, _registrationType, expiresAt, DEPLOY_NIC_VALUE);
    }

    function registerNameByAuction(
        string domainName,
        uint8 durationInYears,
        uint256 bidHash
    ) public override update isAllowedRegType(RegistrationTypes.Auction) {
        reserve(0);
        require(isNameValid(domainName), DeNsErrors.INVALID_DOMAIN_NAME);
        require(msg.value > _auctionDeposit + DEFAULT_MESSAGE_VALUE, DeNsErrors.NOT_ENOUGH_TOKENS_FOR_AUCTION);
        uint32 requestedExpiresAt = calcRequestedExpiresAtByYears(durationInYears);
        require(requestedExpiresAt < _expiresAt, DeNsErrors.DURATION_LARGER_ROOT_CERT_EXPIRES);


        address subdomainCertificate = getResolve(domainName);

        address sender = msg.sender;
        ParticipantStoragePK storagePk = ParticipantStoragePK(sender, domainName);
        uint128 requestHash = calcRequestHash(storagePk);

        NameIdentityCertificate(subdomainCertificate).isAbleToRegister{
            value: DEFAULT_MESSAGE_VALUE,
            callback: isAbleToRegisterCallback
        }(requestHash);
        TvmCell participantStorageState = buildParticipantStorageStateInit(address(this), requestHash);
        ParticipantStorageData pStorageData = ParticipantStorageData(storagePk, requestedExpiresAt, durationInYears, bidHash);

        new ParticipantStorage{stateInit: participantStorageState, value: 0, flag: SEND_ALL_GAS}(pStorageData);

    }

    function registerInstantName(
        string domainName,
        uint32 durationInSec
    ) public override update isAllowedRegType(RegistrationTypes.Instant) {
        require(msg.value >= _instantBuyPrice, DeNsErrors.NOT_ENOUGH_TOKENS_FOR_INSTANT_BUY);
        require(isNameValid(domainName), DeNsErrors.INVALID_DOMAIN_NAME);
        require(durationInSec < _instantBuyMaxSecDuration, DeNsErrors.DURATION_LARGER_MAX_ALLOWED_FOR_INSTANT_BUY);
        uint32 requestedExpiresAt = calcRequestedExpiresAt(durationInSec);
        require(requestedExpiresAt < _expiresAt, DeNsErrors.DURATION_LARGER_ROOT_CERT_EXPIRES);

        reserve(0);

        address subdomainCertificate = getResolve(domainName);

        address sender = msg.sender;
        ParticipantStoragePK storagePk = ParticipantStoragePK(sender, domainName);
        uint128 requestHash = calcRequestHash(storagePk);

        NameIdentityCertificate(subdomainCertificate).isAbleToRegister{
            value: DEFAULT_MESSAGE_VALUE,
            callback: isAbleToRegisterCallback
        }(requestHash);
        TvmCell participantStorageState = buildParticipantStorageStateInit(address(this), requestHash);
        ParticipantStorageData pStorageData = ParticipantStorageData(storagePk, requestedExpiresAt, 0, 0);

        new ParticipantStorage{stateInit: participantStorageState, value: 0, flag: SEND_ALL_GAS}(pStorageData);
    }

    function isAbleToRegister(uint128 requestHash) public view override returns (bool, uint128, string) {
        reserve(0);
        bool isAble = false;
        if (isAuction()) {
            isAble = _expiresAt <= now + REGISTRATION_PERIOD;
        } else if (isInstantBuy()) {
            isAble = isExpired();
        }
        return{value: 0, flag: SEND_ALL_GAS} (isAble, requestHash, _name);
    }

    /*
    *  Callbacks
    */

    onBounce(TvmSlice slice) external view {
        uint32 functionId = slice.decode(uint32);
        if (functionId == tvm.functionId(isAbleToRegister)) {
            reserve(0);
            (uint32 _, uint128 requestHash) = slice.decodeFunctionParams(isAbleToRegister);
            address pStorage = calcParticipantStorageAddress(requestHash);
            if (isAuction()){
                ParticipantStorage(pStorage).getData{value: 0, flag: SEND_ALL_GAS, callback: onStorageReadCheckAuction}();
            } else if (isInstantBuy()){
                ParticipantStorage(pStorage).getDataAndWithdraw{
                    value: 0,
                    flag: SEND_ALL_GAS,
                    callback: onStorageReadDeployCert
                }(DEPLOY_NIC_VALUE);
            }
            _;
        } else if (functionId == tvm.functionId(DomainAuction.isAbleToParticipate)){
            reserve(0);
            (uint32 _, uint128 requestHash) = slice.decodeFunctionParams(DomainAuction.isAbleToParticipate);
            address pStorage = calcParticipantStorageAddress(requestHash);
            ParticipantStorage(pStorage).prune{
                value: 0,
                flag: SEND_ALL_GAS,
                callback: onStoragePruneDeployAuction
            }();
            _;
        }
    }

    /* work with subdomain callbacks*/

    function onUpdateChildCert(string domain, address sender, bool successful) public view {
        checkIsMessageFromSubdomain(domain);
        reserve(0);
        uint128 requestHash = calcRequestHash(ParticipantStoragePK(sender, domain));
        address pStorage = calcParticipantStorageAddress(requestHash);
        if (successful) {
            ParticipantStorage(pStorage).prune{
                value: 0,
                flag: SEND_ALL_GAS,
                callback: onStoragePrunePayToOwner
            }();
        } else {
            ParticipantStorage(pStorage).prune{
                value: 0,
                flag: SEND_ALL_GAS,
                callback: onStoragePruneReturnFunds
            }();
        }
    }

    function isAbleToRegisterCallback(bool isAvailable, uint128 requestHash, string domainName) public view {
        checkIsMessageFromSubdomain(domainName);
        reserve(0);
        address pStorage = calcParticipantStorageAddress(requestHash);
        if (!isAvailable) {
            ParticipantStorage(pStorage).prune{value: 0, flag: SEND_ALL_GAS, callback: onStoragePruneReturnFunds}();
            return;
        }
        if (isAuction()) {
            DomainAuction(getResolveAuction(domainName)).isAbleToParticipate{
                value: 0,
                flag: SEND_ALL_GAS,
                callback: onCheckAuctionCallback
            }(requestHash);
            return;
        }
        if (isInstantBuy()) {
            ParticipantStorage(pStorage).getData{value: 0, flag: SEND_ALL_GAS, callback: onStorageReadUpdateCert}();
            return;
        }
    }

    /* work with auction callbacks*/

    function onCheckAuctionCallback(uint128 requestHash, string domainName) public view {
        require(msg.sender == getResolveAuction(domainName), DeNsErrors.IS_NOT_AUCTION);
        address pStorage = calcParticipantStorageAddress(requestHash);
        ParticipantStorage(pStorage).prune{
            value: 0,
            flag: SEND_ALL_GAS,
            callback: onStoragePruneReturnFunds
        }();
    }

    function onAuctionCompletionCallback(string domainName, address newOwner, uint32 expiresAt) public override {
        require(msg.sender == getResolveAuction(domainName), DeNsErrors.IS_NOT_AUCTION);
        reserve(0);
        if (newOwner != address(0)) {
            deployCertificate(newOwner, domainName, _registrationType, expiresAt, DEPLOY_NIC_VALUE);
        }
        _owner.transfer({value: 0, flag: SEND_ALL_GAS, bounce: false});
    }

    /* storage read callbacks */

    function onStorageReadCheckAuction(ParticipantStorageData storageData) public view {
        uint128 requestHash = calcRequestHash(storageData.pk);
        checkIsMessageFromStorage(requestHash);
        reserve(0);
        DomainAuction(getResolveAuction(storageData.pk.domainName)).isAbleToParticipate{
            value: 0,
            flag: SEND_ALL_GAS,
            callback: onCheckAuctionCallback
        }(requestHash);
    }

    function onStoragePruneDeployAuction(ParticipantStorageData storageData) public {
        uint128 requestHash = calcRequestHash(storageData.pk);
        checkIsMessageFromStorage(requestHash);
        reserve(0);
        string name = storageData.pk.domainName;
        TvmCell auctionStateInit = buildAuctionStateInit(storageData.pk.domainName);
        address auction = new DomainAuction{
            stateInit: auctionStateInit,
            value: DEPLOY_AUCTION_VALUE
        }(storageData.requestedExpiresAt, calcAuctionDuration(storageData.durationInYears), _auctionFee, _auctionDeposit, _bidCode);
        emit AuctionDeployed(name);
        DomainAuction(auction).setInitialBid{value: 0, flag: SEND_ALL_GAS}(storageData.pk.account, storageData.bidHash);
    }

    function onStoragePrunePayToOwner(ParticipantStorageData storageData) public view {
        uint128 requestHash = calcRequestHash(storageData.pk);
        checkIsMessageFromStorage(requestHash);
        reserve(0);
        _owner.transfer({value: 0, flag: SEND_ALL_GAS, bounce: false});
    }

    function onStoragePruneReturnFunds(ParticipantStorageData storageData) public view {
        uint128 requestHash = calcRequestHash(storageData.pk);
        checkIsMessageFromStorage(requestHash);
        reserve(0);
        storageData.pk.account.transfer({value: 0, flag: SEND_ALL_GAS, bounce: false});
    }

    function onStorageReadDeployCert(ParticipantStorageData storageData) public {
        setupSubdomainCert(storageData, true);
    }

    function onStorageReadUpdateCert(ParticipantStorageData storageData) public {
        setupSubdomainCert(storageData, false);
    }

    function setupSubdomainCert(ParticipantStorageData storageData, bool deploy) private {
        uint128 requestHash = calcRequestHash(storageData.pk);
        checkIsMessageFromStorage(requestHash);
        reserve(0);
        address cert;
        string name = storageData.pk.domainName;
        if (deploy) {
            cert = deployCertificate(address(0), name, _registrationType, 0, DEPLOY_NIC_VALUE);
        } else {
            cert = getResolve(name);
        }
        NameIdentityCertificate(cert).updateCertificate{
            value: 0,
            flag: SEND_ALL_GAS,
            callback: onUpdateChildCert
        }(storageData.pk.account, storageData.requestedExpiresAt);
    }

    /*
     *  Parent functions
     */

    function updateCertificate(
        address newOwner,
        uint32 newExpiresAt
    ) public override onlyParent returns (string, address, bool) {
        reserve(0);
        bool successful = false;
        if (isExpired() || _expiresAt == 0){
            _setOwner(newOwner);
            _setExpiresAt(newExpiresAt);
            emit UpdateCertificate(newOwner, newExpiresAt);
            successful = true;
        }
        return{value: 0, flag: SEND_ALL_GAS} (_name, newOwner, successful);

    }

    /*
     *  Owner functions
     */

    function setOwner(address newOwner) public override update onlyOwner {
        _setOwner(newOwner);
        emit UpdateOwner(newOwner);
    }

    function setRegistrationType(RegistrationTypes newRegistrationType) public override update onlyOwner {
        require(RegistrationTypes.OwnerOnly >= newRegistrationType, DeNsErrors.INVALID_REGISTRATION_TYPE);
        _registrationType = newRegistrationType;
        emit UpdateRegistrationType(newRegistrationType);
    }

    function setInstantBuyPrice(uint128 instantBuyPrice) public override update onlyOwner {
        _instantBuyPrice = instantBuyPrice;
    }

    function setInstantBuyMaxSecDuration(uint32 instantBuyMaxSecDuration) public override update onlyOwner {
        _instantBuyMaxSecDuration = instantBuyMaxSecDuration;
    }

    function setAuctionFee(uint128 auctionFee) public override update onlyOwner {
        _auctionFee = auctionFee;
    }

    function setAuctionDeposit(uint128 auctionDeposit) public override update onlyOwner {
        _auctionDeposit = auctionDeposit;
    }

    function setAddress(address newAddress) public override update onlyOwner {
        _records.A = newAddress;
        emit UpdateRecordAddress(newAddress);
    }

    function setAdnlAddress(string newAdnlAddress) public override update onlyOwner {
        _records.ADNL = newAdnlAddress;
        emit UpdateADNLAddress(newAdnlAddress);
    }

    function addTextRecord(string newTextRecord) public override update onlyOwner {
        return _records.TXT.push(newTextRecord);
    }

    function removeTextRecordByIndex(uint index) public override update onlyOwner {
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

    function reserve(uint128 additional) private view {
        tvm.rawReserve(address(this).balance - msg.value + additional, 2);
    }

    function isExpired() private view returns (bool) {
        return _expiresAt <= now;
    }

    function isInstantBuy() private view returns (bool) {
        return _registrationType == RegistrationTypes.Instant;
    }

    function isAuction() private view returns (bool) {
        return _registrationType == RegistrationTypes.Auction;
    }

    function calcAddress(TvmCell state) private pure returns (address) {
        return address.makeAddrStd(0, tvm.hash(state));
    }

    /*  Auction helper functions */

    function calcAuctionDuration(uint8 durationInYears) private pure returns (uint32) {
        return durationInYears >= 4 ? 28 days : durationInYears * 7 days;
    }

    function buildAuctionStateInit(string name) private view returns (TvmCell) {
        return tvm.buildStateInit({
            contr: DomainAuction,
            varInit: {
                _addressNIC: address(this),
                _relativeDomainName: name
            },
            code: _auctionCode
        });
    }

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
        return calcAddress(storageState);
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

    function getResolve(string domainName) public view override returns (address certificate) {
        TvmCell state = buildNicStateInit(domainName);
        certificate = calcAddress(state);
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
        return _buildNicStateInit(domainName, _path, _name);
    }

    function deployCertificate(
        address owner,
        string domainName,
        RegistrationTypes registrationType,
        uint32 expiresAt,
        uint128 value
    ) internal returns (address) {
        TvmCell state = buildNicStateInit(domainName);
        emit CertificateDeployed(domainName);
        return new CertificateDeployable{
            stateInit: state,
            value: value
        }(owner, expiresAt, registrationType, _certificateCode, _auctionCode, _bidCode, _participantStorageCode);
    }
}
