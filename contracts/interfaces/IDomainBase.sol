pragma ton-solidity ^0.37.0;

interface IDomainBase {
    function getResolve(string domainName) external view returns (address certificate);

    function getOwner() external view returns (address);

    function getCertificateCode() external view returns (TvmCell);

    function getAuctionCode() external view returns (TvmCell);

}
