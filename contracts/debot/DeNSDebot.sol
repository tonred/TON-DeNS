pragma ton-solidity >=0.37.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;
import "common/Debot.sol";
import "common/Terminal.sol";
//import "common/AddressInput.sol";
//import "common/Sdk.sol";
import "common/Menu.sol";


contract DeNSDebot is Debot {

    constructor(string debotAbi, string targetAbi, address targetAddress) public {
        require(tvm.pubkey() == msg.pubkey(), 100);
        tvm.accept();
        init(DEBOT_ABI, debotAbi, targetAbi, targetAddress);
    }

    /*
    * Debot Basic API
    */

    function fetch() public override returns (Context[] contexts) {}

    function start() public override {
        Menu.select("Main menu", "Hello, i'm a DeNS debot.", [
            MenuItem("Exit", "", 0)
            ]);
    }

    function quit() public override {

    }

    function getVersion() public override returns (string name, uint24 semver) {
        (name, semver) = ("DeNS Debot", 4 << 8);
    }

    /*
    * Public
    */

    function setResult() public {
        Terminal.print(0, "Transfer succeeded. Bye!");
    }

}
