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

    struct ReservedDomain {
        address owner;
        string domainName;
        RegistrationTypes registrationType;
    }

    modifier onlyParent {
        require(msg.sender == _parent, DeNsErrors.IS_NOT_OWNER);
        _;
    }

    constructor(
        TvmCell certificateCode,
        TvmCell auctionCode,
        TvmCell participantStorageCode,
        ReservedDomain[] reservedDomains,
        uint128 reservedDomainInitialValue
    ) public {
        require(msg.pubkey() == tvm.pubkey(), 100);
        tvm.accept();

        _certificateCode = certificateCode;
        _auctionCode = auctionCode;
        _participantStorageCode = participantStorageCode;

        for (uint i = 0; i < reservedDomains.length; i++) {
            deployCertificate(
                reservedDomains[i].owner,
                reservedDomains[i].domainName,
                reservedDomains[i].registrationType,
                0xFFFFFFFF,
                reservedDomainInitialValue,
                0
            );
        }
    }

    function setProposalCode(TvmCell proposalCode) public override onlyParent {
        _proposalCode = proposalCode;
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

}
