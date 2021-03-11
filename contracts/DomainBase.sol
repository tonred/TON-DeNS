pragma ton-solidity >=0.37.0;

import "interfaces/IDomainBase.sol";
import {DeNsErrors, RegistrationTypes} from "DeNSLib.sol";
import {CertificateDeployable} from "AbstractNameIdentityCertificate.sol";

abstract contract DomainBase is IDomainBase {
    uint16 constant SEND_ALL_GAS = 128;

    TvmCell _certificateCode;
    TvmCell _auctionCode;
    TvmCell _participantStorageCode;

    /*
     * modifiers
     */


    /*
     *  Getters
     */

    function getCertificateCode() view public override returns (TvmCell) {
        return _certificateCode;
    }

    function getAuctionCode() view public override returns (TvmCell) {
        return _auctionCode;
    }

    /*
    *  Public functions
    */

    /*
     *  Private functions
     */

    function _buildNicStateInit(string domainName, string path, string thisName) internal view returns (TvmCell) {
        if (thisName.byteLength() > 0) {
            if (path.byteLength() > 0) {
                path.append(string("/"));
            }
            path.append(thisName);
        }
        return tvm.buildStateInit({
            contr: CertificateDeployable,
            varInit: {
                _parent: address(this),
                _path: path,
                _name: domainName
            },
            code: _certificateCode
        });
    }

    function isNameValid(string name) internal pure returns (bool) {
        bytes nameBytes = bytes(name);
        for(uint8 i = 0; i < nameBytes.length; i++){
            byte c = nameBytes[i];
            if ( c == 0x2F || c == 0x2E){
                return false;
            }
        }
        return true;
    }
}
