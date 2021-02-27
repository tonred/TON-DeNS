pragma ton-solidity ^0.37.0;

import "interfaces/IDomainBase.sol";

import {CertificateErrors} from "./DeNSLib.sol";


abstract contract DomainBase is IDomainBase {
    TvmCell certificateCode;
    TvmCell auctionCode;

    address owner;

    /*
     * modifiers
     */


    modifier onlyOwner {
        require(msg.sender == owner, CertificateErrors.IS_NOT_OWNER);
        _;
    }

    modifier onlyInternalMessage {
        require(msg.sender != address(0), CertificateErrors.IS_EXT_MSG);
        _;
    }

    constructor() public {
        tvm.accept();
    }

//    onBounce(TvmSlice body) external {
//        /*...*/
//    }

    /*
     *  Getters
     */

    function getResolve(string domainName) view public override returns (address certificate){
        certificate = address(0);
    }

    function getOwner() view public override returns (address){
        return owner;
    }

    function getCertificateCode() view public override returns (TvmCell){
        return certificateCode;
    }

    function getAuctionCode() view public override returns (TvmCell){
        return auctionCode;
    }

    /*
    *  Public functions
    */

    function checkDomainCallback() public {
        //TODO check where from message

    }


    /*
     *  Private functions
     */

    function splitDomain(string domainName) private returns (string, string){}

}
