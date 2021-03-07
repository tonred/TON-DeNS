require('dotenv').config({path: './.env'});
const TONTestingSuite = require('ton-testing-suite');
const {setupKeyPairs} = require('./utils.js');
const {deployDeNSRoot} = require("./1-deploy-DeNSRoot");
const {deployDeNSDebot} = require("./2-deploy-DeNSDebot");
const {deployTestContracts} = require("./3-deploy-TestContracts");

const giverConfig = {
    address: process.env.GIVER_CONTRACT,
    abi: JSON.parse(process.env.GIVER_ABI),
};
const config = {
    messageExpirationTimeout: 60000
};
console.log(process.env.NETWORK);

const tonWrapper = new TONTestingSuite.TonWrapper({
    network: process.env.NETWORK,
    seed: process.env.SEED,
    giverConfig,
    config,
});
tonWrapper._setupKeyPairs = setupKeyPairs;


(async () => {
    await tonWrapper.setup(10);
    const migration = new TONTestingSuite.Migration(tonWrapper);
    await deployDeNSRoot(tonWrapper, migration);

    // await deployDeNSDebot(tonWrapper, migration);
    if (eval(process.env.IS_TESTING_ENV)){
        await deployTestContracts(tonWrapper, migration)
    }
    process.exit(0);
})();
