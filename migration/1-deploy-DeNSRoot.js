require('dotenv').config({path: './.env'});
const TONTestingSuite = require("ton-testing-suite");
const {loadTonWrapper} = require("./utils");
const {
    loadDeNSRootContract,
    loadDeNSCertContract,
    loadDeNSAuctionContract,
    loadDeNSBidContract,
    loadParticipantStorageContract,
    loadDeNsProposalContract
} = require("./loadContracts");


async function deployDeNSRoot(tonWrapper, migration) {
    const DeNSRootContract = await loadDeNSRootContract(tonWrapper);
    const DeNSCertContract = await loadDeNSCertContract(tonWrapper);
    const DeNSAuctionContract = await loadDeNSAuctionContract(tonWrapper);
    const DeNSBidContract = await loadDeNSBidContract(tonWrapper);
    const ParticipantStorageContract = await loadParticipantStorageContract(tonWrapper);
    const DeNsProposalContract = await loadDeNsProposalContract(tonWrapper);
    const reservedDomains = TONTestingSuite.utils.loadJSONFromFile(process.env.RESERVED_DOMAINS).map(i => ({
        owner: i.owner,
        domainName: TONTestingSuite.utils.stringToBytesArray(i.domainName),
        registrationType: i.registrationType
    }));
    await migration.deploy({
        contract: DeNSRootContract,
        constructorParams: {reservedDomains: reservedDomains},
        initParams: {
            _parent: process.env.ROOT_OWNER_ADDRESS,
            _path: '',
            _name: '',
        },
        initialBalance: TONTestingSuite.utils.convertCrystal('10', 'nano'),
        alias: process.env.ALIAS,
    });

    async function init(name, value) {
        try {
            console.log('DeNSRootContract initialization: ' + name);
            await DeNSRootContract.run(name, value);
        } catch (e) {
            console.log(e);
        }
    }
    await init('setCertificateCode', {certificateCode: DeNSCertContract.code});
    await init('setAuctionCode', {auctionCode: DeNSAuctionContract.code});
    console.log(DeNSBidContract.code);
    await init('setBidCode', {bidCode: DeNSBidContract.code});
    await init('setParticipantStorageCode', {participantStorageCode: ParticipantStorageContract.code});
    await init('setProposalCode', {proposalCode: DeNsProposalContract.code});

    await init('initReservedDomains', {
        reservedDomainInitialValue: TONTestingSuite.utils.convertCrystal('2', 'nano')
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

