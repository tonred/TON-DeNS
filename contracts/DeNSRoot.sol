pragma ton-solidity >=0.37.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import {RegistrationTypes} from "DeNSLib.sol";
import 'interfaces/IDeNSRoot.sol';
import 'DomainBase.sol';
import 'DeNsProposal.sol';
import {CertificateDeployable} from "AbstractNameIdentityCertificate.sol";

contract DeNSRoot is DomainBase, IDeNSRoot {
    address static _parent;

    string static _path;
    string static _name;

    TvmCell public _proposalCode;
    ReservedDomain[] public _reservedDomains;

    bool _isReservedDomainsInitialized;

    struct ReservedDomain {
        address owner;
        string domainName;
        RegistrationTypes registrationType;
    }

    /*
     * modifiers
     */
    
    modifier onlyParent {
        require(msg.sender == _parent, DeNsErrors.IS_NOT_OWNER);
        _;
    }

    modifier onlyDeployerAndAccept {
        require(msg.pubkey() == tvm.pubkey(), 100);
        tvm.accept();
        _;
    }

    modifier isNotInitialized {
        require(!_isReservedDomainsInitialized, DeNsErrors.RESERVED_DOMAINS_ALREADY_INITIALIZED);
        _;
    }

    constructor(ReservedDomain[] reservedDomains) public onlyDeployerAndAccept {
        _reservedDomains = reservedDomains;
        _isReservedDomainsInitialized = false;
    }

    function setCertificateCode(
        TvmCell certificateCode
    ) public override onlyDeployerAndAccept isNotInitialized {
        _certificateCode = certificateCode;
    }

    function setAuctionCode(
        TvmCell auctionCode
    ) public override onlyDeployerAndAccept isNotInitialized {
        _auctionCode = auctionCode;
    }

    function setParticipantStorageCode(
        TvmCell participantStorageCode
    ) public override onlyDeployerAndAccept isNotInitialized {
        _participantStorageCode = participantStorageCode;
    }

    function setProposalCode(
        TvmCell proposalCode
    ) public override onlyDeployerAndAccept isNotInitialized {
        _proposalCode = proposalCode;
    }

    function initReservedDomains(
        uint128 reservedDomainInitialValue
    ) public override onlyDeployerAndAccept isNotInitialized {
        require(
            isNotEpmty(_certificateCode) && isNotEpmty(_auctionCode) && isNotEpmty(_participantStorageCode),
            DeNsErrors.IMAGES_NOT_INITIALIZED
        );
        require(
            address(this).balance + 1 ton > _reservedDomains.length * reservedDomainInitialValue,
            DeNsErrors.NOT_ENOUGH_BALANCE_FOR_INITIALIZATION
        );
        _isReservedDomainsInitialized = true;
        for (uint i = 0; i < _reservedDomains.length; i++) {
            deployCertificate(
                _reservedDomains[i].owner,
                _reservedDomains[i].domainName,
                _reservedDomains[i].registrationType,
                0xFFFFFFFF,
                reservedDomainInitialValue,
                0
            );
        }
    }

    function createDomainProposal(
        string name,
        address owner,
        RegistrationTypes registrationType,
        address smv,
        uint32 totalVotes,
        uint32 start,
        uint32 end,
        string description,
        string text,
        VoteCountModel model
    ) public override onlyParent {
        tvm.rawReserve(address(this).balance - msg.value, 2);
        TvmCell proposalState = buildProposalStateInit(name, smv);
        new DeNsProposal{
            stateInit: proposalState,
            value: 0,
            flag: SEND_ALL_GAS
        }(owner, registrationType, totalVotes, start, end, description, text, model);
    }

    function onProposalCompletion(
        string name,
        address smv,
        bool result,
        address owner,
        RegistrationTypes registrationType
    ) public {
        TvmCell proposalState = buildProposalStateInit(name, smv);
        require(msg.sender == address.makeAddrStd(0, tvm.hash(proposalState)), DeNsErrors.IS_NOT_PROPOSAL);
        tvm.rawReserve(address(this).balance - msg.value, 2);
        if (result) {
            deployCertificate(owner, name, registrationType, 0xFFFFFFFF, 0, SEND_ALL_GAS);
            return;
        }
        _parent.transfer({value: 0, flag: SEND_ALL_GAS});

    }

    function buildProposalStateInit(string name, address smv) private view returns (TvmCell) {
        return tvm.buildStateInit({
            contr: DeNsProposal,
            varInit: {
                _root: address(this),
                _smv: smv,
                _name: name
            },
            code: _proposalCode
        });
    }

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
        return _buildNicStateInit(domainName, _path, _name);
    }

    function deployCertificate(
        address owner,
        string domainName,
        RegistrationTypes registrationType,
        uint32 expiresAt,
        uint128 value,
        uint16 flag
    ) internal returns (address) {
        TvmCell state = buildNicStateInit(domainName);
        return new CertificateDeployable{
            stateInit: state,
            value: value,
            flag: flag
        }(owner, expiresAt, registrationType, _certificateCode, _auctionCode, _participantStorageCode);
    }

    function isNotEpmty(TvmCell cell) private pure returns (bool) {
        return cell.depth() > 0;
    }

}
