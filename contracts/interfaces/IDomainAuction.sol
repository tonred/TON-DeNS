pragma ton-solidity ^0.37.0;

interface IDomainAuction {
    /* Getters */
    function getAddressNIC() external view returns (address);

    function getRelativeDomainName() external view returns (string);

    function getDomainExpiresAt() external view returns (uint32);

    function getPhase() external returns (Phase);

    function getOpenTime() external view returns (PhaseTime);

    function getConfirmationTime() external view returns (PhaseTime);

    function getCloseTime() external view returns (PhaseTime);

    function getCurrentBidsCount() external view returns (uint64);

    /* Bids functions */
    function makeBid(uint256 bidHash) external public;

    function removeBid() external public;

    function confirmBid(uint128 bidValue, uint256 salt) external public;

    function update() external;

    /* History functions ? */
}
