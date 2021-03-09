const {expect} = require('chai');
const logger = require('mocha-logger');
const TONTestingSuite = require("ton-testing-suite");
const {loadDeNSAuctionContract} = require("../migration/loadContracts");
const {loadTestingEnv} = require("./utils");

const {ARTIFACTS_PATH, ALIAS, tonWrapper} = loadTestingEnv();

let DomainAuction;

describe('Test Domain Auction', async function () {
    this.timeout(12000000);

    before(async function () {
        await tonWrapper.setup();
        DomainAuction = await loadDeNSAuctionContract(tonWrapper);
        await DomainAuction.loadMigration(ALIAS);
        logger.log(`Domain Auction contract address: ${DomainAuction.address}`);
    });

    describe('Check Domain Auction initial configuration', async function () {
        it('Check relative domain name', async function () {
            expect(await DomainAuction.runLocal('getRelativeDomainName'))
                .to
                .equal(TONTestingSuite.utils.stringToBytesArray('test'), 'Wrong relative domain name');
        });
    });
});
