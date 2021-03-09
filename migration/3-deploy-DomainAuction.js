const TONTestingSuite = require("ton-testing-suite");
const {loadDeNSAuctionContract} = require("./loadContracts");


async function deployDeNSAuction(tonWrapper, migration) {
    const DeNSAuctionContract = await loadDeNSAuctionContract(tonWrapper);
    await migration.deploy({
        contract: DeNSAuctionContract,
        constructorParams: {
            thisDomainExpiresAt: Math.round(Date.now() / 1000) + 3600,
            auctionDuration: 60,
        },
        initParams: {
            addressNIC: '0:841288ed3b55d9cdafa806807f02a0ae0c169aa5edfe88a789a6482429756a94',
            relativeDomainName: TONTestingSuite.utils.stringToBytesArray('test'),
        },
        initialBalance: TONTestingSuite.utils.convertCrystal('11', 'nano'),
        alias: process.env.ALIAS,
    });
    return DeNSAuctionContract

}

module.exports = {
    deployDeNSAuction: deployDeNSAuction
}

