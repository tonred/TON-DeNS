const {expect} = require('chai');
const logger = require('mocha-logger');
const TONTestingSuite = require("ton-testing-suite");
const {
    loadDeNSAuctionContract,
    loadDeNSCertContract,
    loadDeNSRootContract,
} = require("../migration/loadContracts");
const {loadTestingEnv} = require("./utils");

const {ARTIFACTS_PATH, ALIAS, tonWrapper} = loadTestingEnv();

let DeNSRootContract;
let NameIdentityCertificate;
let DomainAuction;

describe('Test DeNS Root', async function () {
    this.timeout(12000000);

    before(async function () {
        await tonWrapper.setup();
        DeNSRootContract = await loadDeNSRootContract(tonWrapper);
        NameIdentityCertificate = await loadDeNSCertContract(tonWrapper);
        DomainAuction = await loadDeNSAuctionContract(tonWrapper);
        await DeNSRootContract.loadMigration(ALIAS);
        logger.log(`DeNS Root contract address: ${DeNSRootContract.address}`);
    });

    describe('Check DeNS Root initial configuration', async function () {
        it('Check SMV(parent) address', async function () {
            expect(await DeNSRootContract.runLocal('getParent'))
                .to
                .equal(process.env.ROOT_OWNER_ADDRESS, 'Wrong Root owner');
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
        const reservedDomains = TONTestingSuite.utils.loadJSONFromFile(process.env.RESERVED_DOMAINS);
        reservedDomains.map(async (domain) => {
            it(`Check "${domain.domainName}" Domain`, async function () {
                let domainAddress = await DeNSRootContract.runLocal('getResolve', {
                    domainName: TONTestingSuite.utils.stringToBytesArray(domain.domainName)
                });
                let ReservedNameIdentityCertificate = await loadDeNSCertContract(tonWrapper);
                ReservedNameIdentityCertificate.address = domainAddress;
                expect((await ReservedNameIdentityCertificate.runLocal('getName')).toString())
                    .to
                    .equal(domain.domainName, 'Wrong domain name saved in top-level NIC');
                expect((await ReservedNameIdentityCertificate.runLocal('getPath')).toString())
                    .to
                    .equal("", 'Wrong path in top-level NIC');
                expect(await ReservedNameIdentityCertificate.runLocal('getParent'))
                    .to
                    .equal(DeNSRootContract.address, 'Wrong parent address in top-level NIC');
                expect((await ReservedNameIdentityCertificate.runLocal('getRegistrationType')).toNumber())
                    .to
                    .equal(domain.registrationType, 'Wrong registration type in top-level NIC');
                expect(await ReservedNameIdentityCertificate.runLocal('getOwner'))
                    .to
                    .equal(domain.owner, 'Wrong owner in top-level NIC');
            });
        })
    });
});
