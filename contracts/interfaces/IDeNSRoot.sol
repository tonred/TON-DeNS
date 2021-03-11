pragma ton-solidity >=0.37.0;
import {RegistrationTypes, VoteCountModel} from "../DeNSLib.sol";

interface IDeNSRoot {
    function createDomainProposal(
        string name,
        address owner,
        RegistrationTypes registrationType,
        address smv,
        uint32 totalVotes,
        uint32 start,
        uint32 end,
        string description,
        string text,
        VoteCountModel model
    ) external;

    function getResolve(string domainName) external view returns (address);

    function getParent() external view returns (address);

    function getPath() external view returns (string);

    function getName() external view returns (string);

}
