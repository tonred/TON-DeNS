pragma ton-solidity ^0.37.0;

import {AuctionPhase, AuctionPhaseTime} from "../DeNSLib.sol";


interface IDomainAuction {
    /* Getters */
    function getAddressNIC() external view returns (address);

    function getRelativeDomainName() external view returns (string);

    function getDomainExpiresAt() external view returns (uint32);

    function getPhase() external view returns (AuctionPhase);

    function getOpenTime() external view returns (AuctionPhaseTime);

    function getConfirmationTime() external view returns (AuctionPhaseTime);

    function getCloseTime() external view returns (AuctionPhaseTime);

    function getCurrentBidsCount() external view returns (uint64);

    /* Bids functions */
    function makeBid(uint256 bidHash) external;

    function removeBid() external;

    function confirmBid(uint128 bidValue, uint256 salt) external;

    function calcHash(uint128 bidValue, uint256 salt) external pure returns (uint256);

    function update() external;

    /* History functions ? */
}
