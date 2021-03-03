pragma ton-solidity ^0.37.0;

interface IDomainAuction {
    /* Getters */
    function getAddressNIC() external pure returns (address);

    function getRelativeDomainName() external pure returns (string);

    function getDomainRegisterDuration() external pure returns (uint32);

    function getPhase() external pure returns (Phase);

    function getOpenTime() external pure returns (PhaseTime);

    function getConfirmationTime() external pure returns (PhaseTime);

    function getCloseTime() external pure returns (PhaseTime);

    /* Bids functions */
    function makeBid(string bidHash) external returns (string);

    function removeBid(string bidHash) external returns (string);

    function confirmBid(uint64 bid, uint256 salt) external returns (string);

    function update() external;

    /* History functions ? */
}
