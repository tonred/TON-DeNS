pragma ton-solidity ^0.37.0;

import 'interfaces/IDeNSRoot.sol';
import 'DomainBase.sol';
import {RegistrationTypes} from "DeNSLib.sol";
import {CertificateDeployable} from "./AbstractNameIdentityCertificate.sol";

contract DeNSRoot is DomainBase, IDeNSRoot {
    // TODO: Move to Base contract after bug with static vars will be fixed
    address static _parent;

    string static _path;
    string static _name;

    TvmCell _participantStorageCode;


    struct ReservedDomain {
        string domainName;
        RegistrationTypes registrationType;
    }

    modifier onlyParent {
        require(msg.sender == _parent, CertificateErrors.IS_NOT_OWNER);
        _;
    }

    constructor(TvmCell certificateCode, TvmCell auctionCode, TvmCell participantStorageCode, ReservedDomain[] reservedDomains) public {
    // TODO check message from owner;
        tvm.accept();

        _certificateCode = certificateCode;
        _auctionCode = auctionCode;
        _participantStorageCode = participantStorageCode;

        for (uint i = 0; i < reservedDomains.length; i++) {
            deployCertificate(reservedDomains[i].domainName, reservedDomains[i].registrationType, 0xFFFFFFFF, 10 ton);
        }
    }

    // TODO: STATIC FIX
    function getResolve(string domainName) view public override returns (address){
        TvmCell state = buildNicStateInit(domainName);
        return address.makeAddrStd(0, tvm.hash(state));
    }

    function getParent() view public override returns (address){
        return _parent;
    }

    function getPath() view public override returns (string){
        return _path;
    }

    function getName() view public override returns (string){
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
