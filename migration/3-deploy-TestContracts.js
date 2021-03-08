const TONTestingSuite = require("ton-testing-suite");
const {
    loadTestNicContract,
    loadTestAuctionContract,
    loadTestRootContract,
    loadTestWalletContract
} = require("./loadContracts");
const ALIAS = 'Test' + process.env.ALIAS;


async function deployTestContracts(tonWrapper, migration) {
    const TestWalletContract = await loadTestWalletContract(tonWrapper);
    await migration.deploy({
        contract: TestWalletContract,
        constructorParams: {},
        initialBalance: TONTestingSuite.utils.convertCrystal('10000', 'nano'),
        alias: ALIAS,
    });

    //
    // const TestRootContract = await loadTestRootContract(tonWrapper);
    // const TestNicContract = await loadTestNicContract(tonWrapper);
    // const TestAuctionContract = await loadTestAuctionContract(tonWrapper);
    //
    // await migration.deploy({
    //     contract: TestRootContract,
    //     constructorParams: {},
    //     initialBalance: TONTestingSuite.utils.convertCrystal('10', 'nano'),
    //     alias: ALIAS,
    // });
    // await migration.deploy({
    //     contract: TestNicContract,
    //     constructorParams: {},
    //     initialBalance: TONTestingSuite.utils.convertCrystal('100', 'nano'),
    //     alias: ALIAS,
    // });
    // await TestNicContract.runLocal('spilt', {input: TONTestingSuite.utils.stringToBytesArray('test')});
    // console.log((await TestNicContract.runLocal('test', {})).toNumber())

}

module.exports = {
    deployTestContracts: deployTestContracts
}

