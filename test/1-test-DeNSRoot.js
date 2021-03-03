require('dotenv').config({path: './.env'});
const logger = require('mocha-logger');
const {expect} = require('chai');
const TONTestingSuite = require("ton-testing-suite");

const ARTIFACTS_PATH = process.env.ARTIFACTS_PATH
const ALIAS = process.env.ALIAS

console.log(process.env.NETWORK);

const giverConfig = {
    address: process.env.GIVER_CONTRACT,
    abi: JSON.parse(process.env.GIVER_ABI),
};
const config = {
    messageExpirationTimeout: 60000
};

const tonWrapper = new TONTestingSuite.TonWrapper({
    network: process.env.NETWORK,
    seed: process.env.SEED,
    giverConfig,
    config,
});

let DeNSRootContract;
let NameIdentityCertificate;
let DomainAuction;

describe('Test DeNS Root', async function () {
    this.timeout(12000000);

    before(async function () {
        await tonWrapper.setup();
        DeNSRootContract = await TONTestingSuite.requireContract(tonWrapper, process.env.DNS_ROOT_CONTRACT, undefined, ARTIFACTS_PATH);
        NameIdentityCertificate = await TONTestingSuite.requireContract(tonWrapper, process.env.DNS_NIC_CONTRACT, undefined, ARTIFACTS_PATH);
        DomainAuction = await TONTestingSuite.requireContract(tonWrapper, process.env.DNS_AUCTION_CONTRACT, undefined, ARTIFACTS_PATH);
        await DeNSRootContract.loadMigration(ALIAS);
        logger.log(`DeNS Root contract address: ${DeNSRootContract.address}`);
    });

    describe('Check DeNS Root initial configuration', async function () {
        it('Check SMV(parent) address', async function () {
            expect(await DeNSRootContract.runLocal('getParent'))
                .to
                .equal(process.env.SMV_ADDRESS, 'Wrong SMV address');
        });
        it('Check DeNS Root name', async function () {
            expect(await DeNSRootContract.runLocal('getName'))
                .to
                .have.lengthOf(0, 'DeNS Root name not empty');
        });
        it('Check DeNS Root path', async function () {
            expect(await DeNSRootContract.runLocal('getPath'))
                .to
                .have.lengthOf(0, 'DeNS Root path not empty');
        });
        it('Check installed NIC contract code', async function () {
            expect(await DeNSRootContract.runLocal('getCertificateCode'))
                .to
                .equal(NameIdentityCertificate.code, 'Wrong NIC contract code');
        });
        it('Check installed Auction contract code', async function () {
            expect(await DeNSRootContract.runLocal('getAuctionCode'))
                .to
                .equal(DomainAuction.code, 'Wrong Auction contract code');
        });
    });

    describe('Check Reserved(top-level) domains', async function () {
        const reservedDomains = JSON.parse(process.env.RESERVED_DOMAINS);
        reservedDomains.map(async (domain) => {
            it(`Check "${domain.domainName}" Domain`, async function () {
                let domainAddress = await DeNSRootContract.runLocal('getResolve', {
                    domainName: TONTestingSuite.utils.stringToBytesArray(domain.domainName)
                });
                let ReservedNameIdentityCertificate = await TONTestingSuite.requireContract(
                    tonWrapper,
                    process.env.DNS_NIC_CONTRACT,
                    domainAddress,
                    ARTIFACTS_PATH
                );
                let reservedNicName = await ReservedNameIdentityCertificate.runLocal('getName');
                expect(reservedNicName.toString())
                    .to
                    .equal(domain.domainName, 'Wrong domain name saved in top-level NIC');
                expect(await ReservedNameIdentityCertificate.runLocal('getPath'))
                    .to
                    .have.lengthOf(0, 'Wrong path in top-level NIC');
                expect(await ReservedNameIdentityCertificate.runLocal('getParent'))
                    .to
                    .equal(DeNSRootContract.address, 'Wrong parent address in top-level NIC');
            });
        })
    });
});
