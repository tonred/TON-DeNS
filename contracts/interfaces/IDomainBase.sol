pragma ton-solidity ^0.37.0;

interface IDomainBase {

    function getCertificateCode() external view returns (TvmCell);

    function getAuctionCode() external view returns (TvmCell);

}
