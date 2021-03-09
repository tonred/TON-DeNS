const TONTestingSuite = require("ton-testing-suite");
const {loadDeNSRootContract, loadDeNSDebotContract, loadDeNSCertContract} = require("./loadContracts");


async function deployDeNSDebot(tonWrapper, migration) {
    const DeNSRootContract = await loadDeNSRootContract(tonWrapper);
    const DeNSDebotContract = await loadDeNSDebotContract(tonWrapper);
    const DeNSCertContract = await loadDeNSCertContract(tonWrapper);
    await DeNSRootContract.loadMigration(process.env.ALIAS);
    await migration.deploy({
        contract: DeNSDebotContract,
        constructorParams: {
            debotAbi: TONTestingSuite.utils.stringToBytesArray(JSON.stringify(DeNSDebotContract.abi)),
            targetAbi: TONTestingSuite.utils.stringToBytesArray(JSON.stringify(DeNSCertContract.abi)),
            targetAddress: DeNSRootContract.address,
        },
        initParams: {},
        initialBalance: TONTestingSuite.utils.convertCrystal('11', 'nano'),
        alias: 'DeBot' + process.env.ALIAS,
    });
    return DeNSDebotContract

}

module.exports = {
    deployDeNSDebot: deployDeNSDebot
}

