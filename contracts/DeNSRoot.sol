pragma ton-solidity ^0.37.0;

import 'interfaces/IDeNSRoot.sol';
import 'DomainBase.sol';
import 'NameIdentityCertificate.sol';


contract DeNSRoot is DomainBase, IDeNSRoot {
    address static SMVAddress;

    struct ReservedDomain{
        string domainName;
        uint8 registrationType;
    }

    modifier onlySMV {
        require(msg.sender == SMVAddress, CertificateErrors.IS_NOT_OWNER);
        _;
    }

    constructor(TvmCell certificateCode_, TvmCell auctionCode_, ReservedDomain[] reservedDomains) public {
        tvm.accept();
        certificateCode = certificateCode_;
        auctionCode = auctionCode_;
        for (uint i=0; i<reservedDomains.length; i++) {
            deployCertificate(reservedDomains[i]);
        }
    }

    function getSMVAddress() view public override returns (address){
        return SMVAddress;
    }


    function deployCertificate(ReservedDomain reservedDomain) private{
        TvmCell state = tvm.buildStateInit({
            contr: NameIdentityCertificate,
            varInit: {parent: address(this), absoluteDomainName: reservedDomain.domainName, relativeDomainName: reservedDomain.domainName},
            code: certificateCode
        });
        address cert = new NameIdentityCertificate {stateInit: state, value: 1 ton}();
    }

}
