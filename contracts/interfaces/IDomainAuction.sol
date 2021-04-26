pragma ton-solidity >=0.37.0;

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

    function getBidsCount() external view returns (uint128);

    function getConfirmedBidsCount() external view returns (uint128);

    /* Bids functions */
    function makeBid(uint256 hash) external;

    function removeBid(uint256 hash) external view;

    function confirmBid(uint128 value, uint256 salt) external view;

    function update() external;

    function calcBidHash(uint128 value, uint256 salt) external pure returns (uint256);

    /* History functions ? */
}
