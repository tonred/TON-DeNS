pragma ton-solidity ^0.37.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "common/Debot.sol";
import "common/Terminal.sol";
import "common/AddressInput.sol";
import "common/Sdk.sol";
import "common/Menu.sol";
import "./../interfaces/INameIdentityCertificate.sol";
import {stringUtils} from '../utils.sol';

contract DeNSDebot is Debot {

    address densRootAddress;

    string m_resolvableDomainFirstPart;
    string m_resolvableDomainSecondPart;

    constructor(string debotAbi, string targetAbi, address targetAddress) public {
        require(tvm.pubkey() == msg.pubkey(), 100);
        tvm.accept();
        init(DEBOT_ABI, debotAbi, targetAbi, targetAddress);
        densRootAddress = targetAddress;
    }

    function fetch() public override returns (Context[] contexts) {}

    function start() public override {
        Menu.select("Main menu", "Hello, I am a DeNS debot. Select operation:", [
            MenuItem("Resolve domain", "", tvm.functionId(menuResolveDomain)),
            MenuItem("Do whois operation", "", tvm.functionId(menuWhois)),
            MenuItem("Exit", "", 0)
            ]);
    }

    function quit() public override {
    }

    function getVersion() public override returns (string name, uint24 semver) {
        (name, semver) = ("DeNS Debot", 4 << 8);
    }

    /*
    * Resolve domain
    */

    function menuResolveDomain(uint32 index) public {
        Terminal.inputStr(tvm.functionId(resolveDomain), "Enter domain to resolve: ", false);
    }

    function resolveDomain(string value) public {
        setResolvableDomainParts(value);
        resolve(m_resolvableDomainFirstPart, densRootAddress);
    }

    function setResolvableDomainParts(string value) public {
        (string firstPart, string secondPart) = stringUtils.splitBySlash(value);
        m_resolvableDomainFirstPart = firstPart;
        m_resolvableDomainSecondPart = secondPart;
    }

    function resolve(string domainValue, address parentDomain) public {
        INameIdentityCertificate(parentDomain).getResolve{
                abiVer: 2,
                extMsg: true,
                callbackId: tvm.functionId(resolveNext),
                onErrorId: 0,
                time: 0,
                expire: 0,
                sign: false
        }(domainValue);
    }

    function resolveNext(address domain) public {
        if (domain == address(0)){
            Terminal.print(0, "Domain doesn't exist");
        } else if(m_resolvableDomainSecondPart != "") {
            setResolvableDomainParts(m_resolvableDomainSecondPart);
            resolve(m_resolvableDomainFirstPart, domain);
        } else {
            Terminal.print(0, format("Domain is resolved: {}", domain));
        }
    }


    /*
    * Whois
    */

    function menuWhois(uint32 index) public {
        Terminal.inputStr(tvm.functionId(whois), "Enter domain to do whois operation:", false);
    }

    function whois(string value) public {

    }
}
