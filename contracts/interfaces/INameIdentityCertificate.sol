pragma ton-solidity ^0.37.0;
import {WhoIsInfo, Records} from "../DeNSLib.sol";

interface INameIdentityCertificate {
    /*  Getters  */
    function getParent() external view returns (address);

    function getAbsoluteDomainName() external view returns (string);

    function getRelativeDomainName() external view returns (string);

    function getAddress() external view returns (address);

    function getAdnlAddress() external view returns (string);

    function getTextRecords() external view returns (string[]);

    function getRecords() external view returns (Records);

    function getWhoIs() external view returns (WhoIsInfo);

    function getRegistrationType() external view returns (uint8);

    function getExpiresAt() external view returns (uint32);

    function getOwner() external view returns (address);

    /*  Parent functions  */
    function updateCertificate(address newOwner, uint32 newExpiresAt) external;

    /*  Owner functions  */
    function setOwner(address newOwner) external;

    function setRegistrationType(uint8 newRegistrationType) external;

    function setAddress(address newAddress) external;

    function setAdnlAddress(string newAdnlAddress) external;

    function addTextRecord(string newTextRecord) external;

    function removeTextRecordByIndex(uint index) external;
}
