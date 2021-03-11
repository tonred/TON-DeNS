pragma ton-solidity >=0.37.0;

import {DeNsErrors, RegistrationTypes, VoteCountModel} from "DeNSLib.sol";

interface ISDeNsRoot {
    function onProposalCompletion(
        string name,
        address smv,
        bool result,
        address owner,
        RegistrationTypes registrationType
    ) external;

}

interface IDemiurge {
    function deployProposal(
        uint32 totalVotes,
        uint32 start,
        uint32 end,
        string description,
        string text,
        VoteCountModel model
    ) external;
}

contract DeNsProposal{
    address static _root;
    address static _smv;
    string static _name;

    uint32 _id;
    address _owner;
    RegistrationTypes _registrationType;
    uint32 _totalVotes;
    uint32 _start;
    uint32 _end;
    string _description;
    string _text;
    VoteCountModel _model;

    modifier onlySmv {
        require(msg.sender == _smv, DeNsErrors.IS_NOT_SMV);
        _;
    }

    modifier onlyRoot {
        require(msg.sender == _root, DeNsErrors.IS_NOT_ROOT);
        _;
    }
    constructor(
        address owner,
        RegistrationTypes registrationType,
        uint32 totalVotes,
        uint32 start,
        uint32 end,
        string description,
        string text,
        VoteCountModel model
    ) public onlyRoot {
        _owner = owner;
        _registrationType = registrationType;
        _totalVotes = totalVotes;
        _start = start;
        _end = end;
        _description = description;
        _text = text;
        _model = model;
        deployProposal();
    }

    function deployProposal() private view {
        tvm.rawReserve(address(this).balance - msg.value - 5 ton, 2);
        IDemiurge(_smv).deployProposal{
            value: 0,
            flag: 128
        }(_totalVotes, _start, _end, _description, _text, _model);
    }

    function onProposalDeployed(uint32 id, address _) public onlySmv { _id = id; _;}

    function onProposalCompletion(uint32 _, bool result) public view onlySmv {
        ISDeNsRoot(_root).onProposalCompletion{value: 0, flag: 160}(_name, _smv, result, _owner, _registrationType);
        _;
    }

    function getId() public view returns (uint32) { return _id; }

}
