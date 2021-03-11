require('dotenv').config({path: './.env'});
const TONTestingSuite = require('ton-testing-suite');
const {loadTonWrapper} = require("./utils");
const {setupKeyPairs} = require('./utils.js');
const {deployDeNSRoot} = require("./1-deploy-DeNSRoot");
const {deployDeNSDebot} = require("./2-deploy-DeNSDebot");
const {deployTestContracts} = require("./4-deploy-TestContracts");
const {deployDeNSAuction} = require("./3-deploy-DomainAuction");


(async () => {
    const tonWrapper = await loadTonWrapper();

    await tonWrapper.setup(10);
    const migration = new TONTestingSuite.Migration(tonWrapper);
    await deployDeNSRoot(tonWrapper, migration);


    await deployDeNSDebot(tonWrapper, migration);
    if (eval(process.env.IS_TESTING_ENV)){
        await deployTestContracts(tonWrapper, migration)
    }
    process.exit(0);
})();
