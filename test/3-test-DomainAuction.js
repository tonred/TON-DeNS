const {expect} = require('chai');
const logger = require('mocha-logger');
const TONTestingSuite = require("ton-testing-suite");
const BigNumber = require('bignumber.js');
const {
    loadDeNSAuctionContract,
    loadDeNSCertContract,
    loadTestWalletContract,
    loadDeNSRootContract
} = require("../migration/loadContracts");
const {loadTestingEnv, copyContract} = require("./utils");

const {ARTIFACTS_PATH, ALIAS, tonWrapper} = loadTestingEnv();
const reservedDomainWithAuctionReg = "os";

let DeNSRootContract;
let DomainAuction;
let TestWalletContract;
let NicContract;
let rootCertAddress;
let rootCert;

async function resolve(cert, name) {
    return await cert.runLocal('getResolve', {
        domainName: TONTestingSuite.utils.stringToBytesArray(name)
    });
}

async function resolveAuction(cert, name) {
    return await cert.runLocal('getResolveAuction', {
        domainName: TONTestingSuite.utils.stringToBytesArray(name)
    });
}


describe('Test Domain Auction', async function () {
    this.timeout(12000000);
    const name = 'test';
    const value = '105';

    before(async function () {
        await tonWrapper.setup();
        DomainAuction = await loadDeNSAuctionContract(tonWrapper);
        NicContract = await loadDeNSCertContract(tonWrapper);
        DeNSRootContract = await loadDeNSRootContract(tonWrapper);
        TestWalletContract = await loadTestWalletContract(tonWrapper);
        await DeNSRootContract.loadMigration(ALIAS);
        await TestWalletContract.loadMigration('Test' + ALIAS);
        rootCertAddress = await resolve(DeNSRootContract, reservedDomainWithAuctionReg)
        rootCert = copyContract(NicContract);
        rootCert.address = rootCertAddress;
        logger.log(`Root Certificate with Auction buy: ${rootCertAddress}`);
    });

    describe('Check Domain Auction initial configuration', async function () {
        let domainExpiresAt;
        let openTime, confirmationTime, closeTime;
        before(async function () {
            DomainAuction.address = await resolveAuction(rootCert, name);
            logger.log(`Domain Auction contract address: ${DomainAuction.address}`);
            await buyDomain(rootCert, name, 10, 111, value);

            domainExpiresAt = await DomainAuction.runLocal('getDomainExpiresAt');
            openTime = await DomainAuction.runLocal('getOpenTime');
            confirmationTime = await DomainAuction.runLocal('getConfirmationTime');
            closeTime = await DomainAuction.runLocal('getCloseTime');

        });

        it('Check address NIC', async function () {
            expect(await DomainAuction.runLocal('getAddressNIC'))
                .to
                .equal(rootCert.address, 'Wrong address NIC');
        });
        it('Check relative domain name', async function () {
            expect((await DomainAuction.runLocal('getRelativeDomainName')).toString())
                .to
                .equal(name, 'Wrong relative domain name');
        });
        it('Check phase', async function () {
            expect((await DomainAuction.runLocal('getPhase')).toString())
                .to
                .equal('0', 'Wrong initial phase');
        });
        it('Check bid remove', async function () {
            await removeBid(DomainAuction, '1');
            expect((await DomainAuction.runLocal('getCurrentBidsCount')).toString())
                .to
                .equal('0', 'Bid not removed');
        });

        it('Check make bid', async function () {
            let salt = randomInt(0, Number.MAX_SAFE_INTEGER);
            let bidValue = 1111;
            let bidHash = BigNumber(await DomainAuction.runLocal('calcHash', {
                bidValue: bidValue, salt: salt,
            })).toFixed();
            logger.log(`First bid: value=${bidValue}, salt=${salt}, bidHash=${bidHash}`);
            await makeBid(DomainAuction, bidHash, value);

            expect((await DomainAuction.runLocal('getCurrentBidsCount')).toString())
                .to
                .equal('1', 'First bids is not made');
        })
    });


});

async function buyDomain(contract, domainName, durationInYears, bidHash, value) {
    const message = await encode_message_body(contract, 'registerNameByAuction', {
        domainName: TONTestingSuite.utils.stringToBytesArray(domainName),
        durationInYears: durationInYears,
        bidHash: bidHash
    })
    return await send(contract.address, message.body, value);
}

function randomInt(min, max) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
}

async function makeBid(contract, bidHash, value) {
    const message = await encode_message_body(contract, 'makeBid', {bidHash: bidHash});
    return await send(contract.address, message.body, value);
}

async function removeBid(contract, value) {
    const message = await encode_message_body(contract, 'removeBid', {});
    return await send(contract.address, message.body, value);
}

async function encode_message_body(contract, function_name, input) {
    return await tonWrapper.ton.abi.encode_message_body({
        address: contract.address,
        abi: {
            type: 'Contract',
            value: contract.abi,
        },
        call_set: {
            function_name: function_name,
            input: input,
        },
        signer: {
            type: 'None',
        },
        is_internal: true,
    });
}

async function send(dest, payload, value) {
    return await TestWalletContract.run('sendTransaction', {
        dest: dest,
        value: TONTestingSuite.utils.convertCrystal(value, 'nano'),
        bounce: true,
        flags: 0,
        payload: payload,
    }, null);
}
