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
import "../DeNSLib.sol";


contract DeNSDebot is Debot {

    address densRootAddress;

    constructor(string debotAbi, address targetAddress) public {
        require(tvm.pubkey() == msg.pubkey(), 100);
        tvm.accept();
        init(DEBOT_ABI, debotAbi, '', targetAddress);
        densRootAddress = targetAddress;
    }

    function fetch() public override returns (Context[] contexts) {}

    function start() public override {
        Menu.select("Main menu", "Hello, I am a DeNS debot. Select operation:", [
            MenuItem("Get address (resolve)", "", tvm.functionId(getAddressMenu)),
            MenuItem("Get whois", "", tvm.functionId(getWhoisMenu)),
            MenuItem("Exit", "", 0)
            ]);
    }

    function quit() public override {
    }

    function getVersion() public override returns (string name, uint24 semver) {
        (name, semver) = ("DeNS Debot", 4 << 8);
    }

    /*
    * Resolve base
    */

    // Dont use struct! It max size is 1023
    string resolveCurrentPath;
    string resolveOtherPath;
    uint8 resolveCallback;  // todo improve

    function resolveSplit(string domain) public {
        (string currentPath, string otherPath) = stringUtils.splitBySlash(domain);
        resolveCurrentPath = currentPath;
        resolveOtherPath = otherPath;
    }

    function resolve(address parentDomain) public {
        if (resolveOtherPath != "") {
            resolveSplit(resolveOtherPath);
            resolveCurrent(parentDomain);
        } else {
            if (resolveCallback == 0) {
                getAddress(parentDomain);
            }
            if (resolveCallback == 1) {
                getWhois(parentDomain);
            }
        }
    }

    function resolveCurrent(address parentDomain) public {
        optional(uint256) pubkey;
        INameIdentityCertificate(parentDomain).getResolve{
            abiVer: 2,
            extMsg: true,
            sign: false,
            pubkey: pubkey,
            time: uint64(now),
            expire: 0,
            callbackId: tvm.functionId(resolve),
            onErrorId: tvm.functionId(resolveError)
        }(resolveCurrentPath);
    }

    function resolveError() public {
        Terminal.print(0, format("Some exception in resolve"));  // dont works
    }

    /*
    * Get address
    */

    string getAddressInput;

    function getAddressMenu(uint32 index) public {
        Terminal.inputStr(tvm.functionId(getAddressStart), "Enter domain: ", false);
    }

    function getAddressStart(string value) public {
        getAddressInput = value;
        resolveOtherPath = value;
        resolveCallback = 0;
//        resolveResult = address.makeAddrNone();
        resolve(densRootAddress);
    }

    function getAddress(address result) public {
        optional(uint256) pubkey;
        INameIdentityCertificate(result).getAddress{
            abiVer: 2,
            extMsg: true,
            sign: false,
            pubkey: pubkey,
            time: uint64(now),
            expire: 0,
            callbackId: tvm.functionId(getAddressResult),
            onErrorId: 0
        }();
    }

    function getAddressResult(address result) public {
        Terminal.print(0, format("Domain '{}' address: {}", getAddressInput, result));
    }

    function getAddressError() public {
        Terminal.print(0, format("Domain '{}' in not exists", getAddressInput));
    }

    /*
    * Get whois
    */

    string getWhoisInput;

    function getWhoisMenu(uint32 index) public {
        Terminal.inputStr(tvm.functionId(getWhoisStart), "Enter domain: ", false);
    }

    function getWhoisStart(string value) public {
        getWhoisInput = value;
        resolveOtherPath = value;
        resolveCallback = 1;
        resolve(densRootAddress);
    }

    function getWhois(address result) public {
        optional(uint256) pubkey;
        INameIdentityCertificate(result).getWhoIs{
            abiVer: 2,
            extMsg: true,
            sign: false,
            pubkey: pubkey,
            time: uint64(now),
            expire: 0,
            callbackId: tvm.functionId(getWhoisResult),
            onErrorId: 0
        }();
    }

    function getWhoisResult(WhoIsInfo result) public {
        Terminal.print(0, format("Whois of '{}' is: {\n\tparent = {}\n\tpath = {}\n\tname = {}\n\towner = {}\n\texpiresAt = {}\n}",
            getWhoisInput, result.parent, result.path, result.name, result.owner, result.expiresAt));
    }

    function getWhoisError() public {
        Terminal.print(0, format("Domain '{}' in not exists", getWhoisInput));
    }
}
