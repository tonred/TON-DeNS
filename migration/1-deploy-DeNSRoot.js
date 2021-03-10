require('dotenv').config({path: './.env'});
const TONTestingSuite = require("ton-testing-suite");
const {loadTonWrapper} = require("./utils");
const {
    loadDeNSRootContract,
    loadDeNSCertContract,
    loadDeNSAuctionContract,
    loadParticipantStorageContract
} = require("./loadContracts");


async function deployDeNSRoot(tonWrapper, migration) {
    const DeNSRootContract = await loadDeNSRootContract(tonWrapper);
    const DeNSCertContract = await loadDeNSCertContract(tonWrapper);
    const DeNSAuctionContract = await loadDeNSAuctionContract(tonWrapper);
    const ParticipantStorageContract = await loadParticipantStorageContract(tonWrapper);
    const reservedDomains = TONTestingSuite.utils.loadJSONFromFile(process.env.RESERVED_DOMAINS).map(i => ({
        owner: i.owner,
        domainName: TONTestingSuite.utils.stringToBytesArray(i.domainName),
        registrationType: i.registrationType
    }));
    await migration.deploy({
        contract: DeNSRootContract,
        constructorParams: {
            certificateCode: DeNSCertContract.code,
            auctionCode: DeNSAuctionContract.code,
            participantStorageCode: ParticipantStorageContract.code,
            reservedDomains
        },
        initParams: {
            _parent: process.env.SMV_ADDRESS,
            _path: '',
            _name: '',
        },
        initialBalance: TONTestingSuite.utils.convertCrystal('110', 'nano'),
        alias: process.env.ALIAS,
    });

}

if (require.main === module) {
    (async () => {
        const _tonWrapper = await loadTonWrapper();
        await _tonWrapper.setup(1);
        const _migration = new TONTestingSuite.Migration(_tonWrapper);
        await deployDeNSRoot(_tonWrapper, _migration)
        process.exit(0);
    })();
}

module.exports = {
    deployDeNSRoot: deployDeNSRoot
}

