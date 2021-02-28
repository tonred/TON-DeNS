const TONTestingSuite = require("ton-testing-suite");
const ARTIFACTS_PATH = process.env.ARTIFACTS_PATH

async function deployDeNSRoot(tonWrapper, migration) {
    const DeNSRootContract = await TONTestingSuite.requireContract(tonWrapper, process.env.DNS_ROOT_CONTRACT, undefined, ARTIFACTS_PATH);
    const DeNSCertContract = await TONTestingSuite.requireContract(tonWrapper, process.env.DNS_NIC_CONTRACT, undefined, ARTIFACTS_PATH);
    const DeNSAuctionContract = await TONTestingSuite.requireContract(tonWrapper, process.env.DNS_AUCTION_CONTRACT, undefined, ARTIFACTS_PATH);
    const reservedDomains = JSON.parse(process.env.RESERVED_DOMAINS).map(i => ({
        domainName: TONTestingSuite.utils.stringToBytesArray(i.domainName),
        registrationType: i.registrationType
    }));
    await migration.deploy({
        contract: DeNSRootContract,
        constructorParams: {
            certificateCode_: DeNSCertContract.code,
            auctionCode_: DeNSAuctionContract.code,
            reservedDomains
        },
        initParams: {
            SMVAddress: process.env.SMV_ADDRESS
        },
        initialBalance: TONTestingSuite.utils.convertCrystal('11', 'nano'),
        _randomNonce: false,
        alias: 'DeNS',
    });
    return DeNSRootContract
}

module.exports = {
    deployDeNSRoot: deployDeNSRoot
}

