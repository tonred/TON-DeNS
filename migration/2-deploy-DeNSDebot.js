require('dotenv').config({path: './.env'});
const TONTestingSuite = require("ton-testing-suite");
const {loadTonWrapper} = require("./utils");
const {loadDeNSRootContract, loadDeNSDebotContract, loadDeNSCertContract} = require("./loadContracts");


async function deployDeNSDebot(tonWrapper, migration) {
    const DeNSRootContract = await loadDeNSRootContract(tonWrapper);
    const DeNSDebotContract = await loadDeNSDebotContract(tonWrapper);
    // const DeNSCertContract = await loadDeNSCertContract(tonWrapper);
    await DeNSRootContract.loadMigration(process.env.ALIAS);
    await migration.deploy({
        contract: DeNSDebotContract,
        constructorParams: {
            debotAbi: TONTestingSuite.utils.stringToBytesArray(JSON.stringify(DeNSDebotContract.abi)),
            // targetAbi: TONTestingSuite.utils.stringToBytesArray(JSON.stringify(DeNSCertContract.abi)),
            targetAddress: DeNSRootContract.address,
        },
        initParams: {},
        initialBalance: TONTestingSuite.utils.convertCrystal('1', 'nano'),
        alias: 'DeBot' + process.env.ALIAS,
    });
    return DeNSDebotContract

}

if (require.main === module) {
    (async () => {
        const _tonWrapper = await loadTonWrapper();
        await _tonWrapper.setup(1);
        const _migration = new TONTestingSuite.Migration(_tonWrapper);
        await deployDeNSDebot(_tonWrapper, _migration)
        process.exit(0);
    })();
}

module.exports = {
    deployDeNSDebot: deployDeNSDebot
}

