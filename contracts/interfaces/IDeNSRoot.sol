pragma ton-solidity ^0.37.0;

interface IDeNSRoot {
//    function getSMVAddress() external view returns (address);


    function getResolve(string domainName) external view returns (address);

    function getParent() external view returns (address);

    function getPath() external view returns (string);

    function getName() external view returns (string);

}
