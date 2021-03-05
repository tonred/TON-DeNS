const TONTestingSuite = require("ton-testing-suite");
const ARTIFACTS_PATH = process.env.ARTIFACTS_PATH

async function deployDomainAuction(tonWrapper, migration) {
    // const DeNSDebotContract = await TONTestingSuite.requireContract(tonWrapper, process.env.DNS_DEBOT_CONTRACT, undefined, ARTIFACTS_PATH);
    const domainAuctionContract = await TONTestingSuite.requireContract(tonWrapper, process.env.DNS_AUCTION_CONTRACT, undefined, ARTIFACTS_PATH);
    await migration.deploy({
        contract: domainAuctionContract,
        constructorParams: {
            thisDomainExpiresAt: Math.round(Date.now() / 1000),
            auctionDuration: 230000,
        },
        initParams: {
            addressNIC: '0:841288ed3b55d9cdafa806807f02a0ae0c169aa5edfe88a789a6482429756a94',
            relativeDomainName: TONTestingSuite.utils.stringToBytesArray('test'),
        },
        initialBalance: TONTestingSuite.utils.convertCrystal('11', 'nano'),
        alias: process.env.ALIAS,
    });
    return domainAuctionContract

}

module.exports = {
    deployDomainAuction: deployDomainAuction
}

