pragma ton-solidity >=0.37.0;
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

    function getInstantBuyPrice() external view returns (uint128);

    function getInstantBuyMaxSecDuration() external view returns (uint32);

    /*  Register name  */
    function registerNameByOwner(string domainName, uint32 expiresAt) external;

    function registerNameByAuction(string domainName, uint8 durationInYears, uint256 bidHash) external;

    function registerInstantName(string domainName, uint32 durationInSec) external;

    /*  callback functions  */

    function onAuctionCompletionCallback(string domainName, address newOwner, uint32 expiresAt) external;

    /*  Parent functions  */
    function updateCertificate(address newOwner, uint32 newExpiresAt) external returns(string, address, bool);

    /*  Owner functions  */
    function setOwner(address newOwner) external;

    function setRegistrationType(RegistrationTypes newRegistrationType) external;

    function setInstantBuyPrice(uint128 instantBuyPrice) external;

    function setInstantBuyMaxSecDuration(uint32 instantBuyMaxSecDuration) external;

    function setAuctionFee(uint128 auctionFee) external;

    function setAuctionDeposit(uint128 auctionDeposit) external;

    function setAddress(address newAddress) external;

    function setAdnlAddress(string newAdnlAddress) external;

    function addTextRecord(string newTextRecord) external;

    function removeTextRecordByIndex(uint index) external;
}
