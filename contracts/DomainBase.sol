pragma ton-solidity ^0.37.0;

import "interfaces/IDomainBase.sol";
import {CertificateErrors} from "./DeNSLib.sol";

abstract contract DomainBase is IDomainBase {
    TvmCell _certificateCode;
    TvmCell _auctionCode;

    /*
     * modifiers
     */


    /*
     *  Getters
     */

    function getCertificateCode() view public override returns (TvmCell){
        return _certificateCode;
    }

    function getAuctionCode() view public override returns (TvmCell){
        return _auctionCode;
    }

    /*
    *  Public functions
    */

    /*
     *  Private functions
     */

    function splitDomain(string domainName) private returns (string, string){}

    function isNameValid(string name) internal pure returns (bool){
        bytes name_bytes = bytes(name);
        for(uint8 i = 0; i < name_bytes.length; i++){
            byte c = name_bytes[i];
            if ( c == 0x2F || c == 0x2E){
                return false;
            }
        }
        return true;
    }
}
