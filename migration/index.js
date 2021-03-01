require('dotenv').config({path: './.env'});
const TONTestingSuite = require('ton-testing-suite');
const {setupKeyPairs} = require('./utils.js');
const {deployDeNSRoot} = require("./1_deploy_DeNSRoot");
const {deployDeNSDebot} = require("./2_deploy_DeNSDebot");

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
    const DeNSRootContract = await deployDeNSRoot(tonWrapper, migration);
    const DeNSDebotContract = await deployDeNSDebot(tonWrapper, migration);

    process.exit(0);
})();
