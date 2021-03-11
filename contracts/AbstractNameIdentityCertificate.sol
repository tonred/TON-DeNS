pragma ton-solidity >=0.37.0;
import {RegistrationTypes} from "DeNSLib.sol";

contract CertificateDeployable{
    address static _parent;

    string static _path;
    string static _name;
    constructor(
        address owner,
        uint32 expiresAt,
        RegistrationTypes registrationType,
        TvmCell certificateCode,
        TvmCell auctionCode,
        TvmCell participantStorageCode
    ) public  {}
}
