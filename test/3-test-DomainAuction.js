const {expect} = require('chai');
const logger = require('mocha-logger');
const TONTestingSuite = require("ton-testing-suite");
const BigNumber = require('bignumber.js');
const {loadDeNSAuctionContract, loadTestWalletContract} = require("../migration/loadContracts");
const {loadTestingEnv} = require("./utils");

const {ARTIFACTS_PATH, ALIAS, tonWrapper} = loadTestingEnv();

let DomainAuction;
let TestWalletContract;


describe('Test Domain Auction', async function () {
    this.timeout(12000000);

    before(async function () {
        await tonWrapper.setup();
        DomainAuction = await loadDeNSAuctionContract(tonWrapper);
        TestWalletContract = await loadTestWalletContract(tonWrapper);
        await DomainAuction.loadMigration(ALIAS);
        await TestWalletContract.loadMigration('Test' + ALIAS);
        logger.log(`Domain Auction contract address: ${DomainAuction.address}`);
    });

    describe('Check Domain Auction initial configuration', async function () {
        let domainExpiresAt;
        let openTime, confirmationTime, closeTime;
        before(async function () {
            domainExpiresAt = await DomainAuction.runLocal('getDomainExpiresAt');
            openTime = await DomainAuction.runLocal('getOpenTime');
            confirmationTime = await DomainAuction.runLocal('getConfirmationTime');
            closeTime = await DomainAuction.runLocal('getCloseTime');
        });

        it('Check address NIC', async function () {
            expect(await DomainAuction.runLocal('getAddressNIC'))
                .to
                .equal('0:841288ed3b55d9cdafa806807f02a0ae0c169aa5edfe88a789a6482429756a94', 'Wrong address NIC');
        });
        it('Check relative domain name', async function () {
            expect((await DomainAuction.runLocal('getRelativeDomainName')).toString())
                .to
                .equal('test', 'Wrong relative domain name');
        });
        it('Check phase', async function () {
            expect((await DomainAuction.runLocal('getPhase')).toString())
                .to
                .equal('0', 'Wrong initial phase');
        });
        it('Check open time duration', async function () {
            expect(openTime.finishTime - openTime.startTime)
                .to
                .equal(60 - 30, 'Wrong open time');
        });
        it('Check confirmation time duration', async function () {
            expect(openTime.finishTime - openTime.startTime)
                .to
                .equal(30, 'Wrong confirmation time');
        });
        it('Check close time', async function () {
            expect(closeTime.finishTime.toString())
                .to
                .equal(domainExpiresAt.toString(), 'Wrong close time');
        });
        it('Check phase order', async function () {
            expect(openTime.finishTime.toString())
                .to
                .equal(confirmationTime.startTime.toString(), 'Open and confirmation phase mismatch');
            expect(confirmationTime.finishTime.toString())
                .to
                .equal(closeTime.startTime.toString(), 'Confirmation and close phase mismatch');
        });
    });

    describe('Check Domain Auction workflow', async function () {
        let firstBidValue = 1000;
        let secondBidValue = 2000;
        it('Make first bid', async function () {
            let salt = randomInt(0, Number.MAX_SAFE_INTEGER);
            let bidHash = BigNumber(await DomainAuction.runLocal('calcHash', {
                bidValue: firstBidValue, salt: salt,
            })).toFixed();
            logger.log(`First bid: value=${firstBidValue}, salt=${salt}, bidHash=${bidHash}`);
            let response = await makeBid(DomainAuction, bidHash, 101);
            expect((await DomainAuction.runLocal('getCurrentBidsCount')).toString())
                .to
                .equal('1', 'First bid is not made');
        });
    });
});


function randomInt(min, max) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
}

async function makeBid(contract, bidHash, value) {
    const message = await tonWrapper.ton.abi.encode_message_body({
        address: contract.address,
        abi: {
            type: 'Contract',
            value: contract.abi,
        },
        call_set: {
            function_name: 'makeBid',
            input: {bidHash: bidHash},
        },
        signer: {
            type: 'None',
        },
        is_internal: true,
    });

    return await TestWalletContract.run('sendTransaction', {
        dest: contract.address,
        value: TONTestingSuite.utils.convertCrystal(value, 'nano'),
        bounce: true,
        flags: 0,
        payload: message.body,
    }, null);
}
