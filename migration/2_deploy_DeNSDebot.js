const TONTestingSuite = require("ton-testing-suite");
const ARTIFACTS_PATH = process.env.ARTIFACTS_PATH

async function deployDeNSDebot(tonWrapper, migration) {
    const DeNSDebotContract = await TONTestingSuite.requireContract(tonWrapper, process.env.DNS_DEBOT_CONTRACT, undefined, ARTIFACTS_PATH);
    const DeNSRootContract = await TONTestingSuite.requireContract(tonWrapper, process.env.DNS_ROOT_CONTRACT, undefined, ARTIFACTS_PATH);
    await DeNSRootContract.loadMigration(process.env.ALIAS);
    await migration.deploy({
        contract: DeNSDebotContract,
        constructorParams: {
            debotAbi: TONTestingSuite.utils.stringToBytesArray(JSON.stringify(DeNSDebotContract.abi)),
            targetAbi: TONTestingSuite.utils.stringToBytesArray(JSON.stringify(DeNSRootContract.abi)),
            targetAddress: DeNSRootContract.address,
        },
        initParams: {},
        initialBalance: TONTestingSuite.utils.convertCrystal('11', 'nano'),
        alias: process.env.ALIAS,
    });
    return DeNSDebotContract

}

module.exports = {
    deployDeNSDebot: deployDeNSDebot
}

