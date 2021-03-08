pragma ton-solidity ^0.37.0;
import {WhoIsInfo, Records, RegistrationTypes} from "../DeNSLib.sol";

interface INameIdentityCertificate {

   function isAbleToRegister(uint128 requestHash) external view returns(bool, uint128, string);

    function getResolve(string domainName) external view returns (address certificate);

    function getParent() external view returns (address);

    function getPath() external view returns (string);

    function getName() external view returns (string);


    /*  Getters  */
    function getAddress() external view returns (address);

    function getAdnlAddress() external view returns (string);

    function getTextRecords() external view returns (string[]);

    function getRecords() external view returns (Records);

    function getWhoIs() external view returns (WhoIsInfo);

    function getRegistrationType() external view returns (RegistrationTypes);

    function getExpiresAt() external view returns (uint32);

    function getOwner() external view returns (address);

    /*  Parent functions  */
    function updateCertificate(address newOwner, uint32 newExpiresAt) external returns(string, address, bool);

    /*  Owner functions  */
    function setOwner(address newOwner) external;

    function setRegistrationType(RegistrationTypes newRegistrationType) external;

    function setAddress(address newAddress) external;

    function setAdnlAddress(string newAdnlAddress) external;

    function addTextRecord(string newTextRecord) external;

    function removeTextRecordByIndex(uint index) external;
}
