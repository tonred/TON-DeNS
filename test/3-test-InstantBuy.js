const {expect} = require('chai');
const logger = require('mocha-logger');
const TONTestingSuite = require("ton-testing-suite");
const {
    loadDeNSCertContract,
    loadTestWalletContract,
    loadDeNSRootContract
} = require("../migration/loadContracts");
const {loadTestingEnv, copyContract} = require("./utils");

const {ARTIFACTS_PATH, ALIAS, tonWrapper} = loadTestingEnv();
const reservedDomainWithInstantReg = "🤗";

let DeNSRootContract;
let NicContract;
let TestWalletContract;
let rootCertAddress;
let rootCert;


describe('Test Instant registration', async function () {
    this.timeout(12000000);

    before(async function () {
        await tonWrapper.setup();
        DeNSRootContract = await loadDeNSRootContract(tonWrapper);
        NicContract = await loadDeNSCertContract(tonWrapper);
        TestWalletContract = await loadTestWalletContract(tonWrapper);
        await DeNSRootContract.loadMigration(ALIAS);
        await TestWalletContract.loadMigration('Test' + ALIAS);
        rootCertAddress = await resolve(DeNSRootContract, reservedDomainWithInstantReg)
        rootCert = copyContract(NicContract);
        rootCert.address = rootCertAddress;
        logger.log(`Root Certificate with instant buy: ${rootCertAddress}`);

    });

    describe(`Check Domain`, async function () {
        let firstSubDomainAddr;
        let firstSubDomainCert;
        let secondSubDomainCert;
        let secondSubDomainAddr;
        let name = 'asd';
        let value = '11';
        let duration = 60 * 60 * 24;

        before(async function () {
            await instantBuyDomain(rootCert, name, duration, value);
            firstSubDomainAddr = await rootCert.runLocal('getResolve', {domainName: TONTestingSuite.utils.stringToBytesArray(name)});
            firstSubDomainCert = copyContract(NicContract);
            firstSubDomainCert.address = firstSubDomainAddr;
            logger.log(`Subdomain Certificate: ${firstSubDomainAddr}`);
            await instantBuyDomain(firstSubDomainCert, name, duration - 100, value);
            secondSubDomainAddr = await firstSubDomainCert.runLocal('getResolve', {domainName: TONTestingSuite.utils.stringToBytesArray(name)});
            secondSubDomainCert = copyContract(NicContract);
            secondSubDomainCert.address = secondSubDomainAddr;
            logger.log(`Sub-Subdomain Certificate: ${secondSubDomainAddr}`);
        });
        it('Check subdomain parent', async function () {
            expect(await firstSubDomainCert.runLocal('getParent'))
                .to
                .equal(rootCert.address, 'Wrong parent');
        });
        it('Check subdomain name', async function () {
            expect((await firstSubDomainCert.runLocal('getName')).toString())
                .to
                .equal(name, 'Wrong name');
        });
        it('Check subdomain expiresAt', async function () {
            expect((await firstSubDomainCert.runLocal('getExpiresAt')).toNumber())
                .to
                .below((await rootCert.runLocal('getExpiresAt')).toNumber(), 'Wrong expiresAt');
        });
        it('Check subdomain owner', async function () {
            expect(await firstSubDomainCert.runLocal('getOwner'))
                .to
                .equal(TestWalletContract.address, 'Wrong owner address');
        });

        it('Check 2subdomain parent', async function () {
            expect(await secondSubDomainCert.runLocal('getParent'))
                .to
                .equal(firstSubDomainCert.address, 'Wrong parent');
        });
        it('Check 2subdomain name', async function () {
            expect((await secondSubDomainCert.runLocal('getName')).toString())
                .to
                .equal(name, 'Wrong name');
        });
        it('Check 2subdomain expiresAt', async function () {
            expect((await secondSubDomainCert.runLocal('getExpiresAt')).toNumber())
                .to
                .below((await firstSubDomainCert.runLocal('getExpiresAt')).toNumber(), 'Wrong expiresAt');
        });
        it('Check 2subdomain owner', async function () {
            expect(await secondSubDomainCert.runLocal('getOwner'))
                .to
                .equal(TestWalletContract.address, 'Wrong owner address');
        });
        it('Check buy with wrong duration', async function () {
            await instantBuyDomain(secondSubDomainCert, name, duration + 100, value);
            let addr = await secondSubDomainCert.runLocal('getResolve', {domainName: TONTestingSuite.utils.stringToBytesArray(name)});
            expect(await getAccountType(addr))
                .to
                .equal(0, 'Domain was expected not to be registered, but it is registered');
        });
        it('Check buy with low value', async function () {
            await instantBuyDomain(secondSubDomainCert, name, duration - 2000, '5');
            let addr = await secondSubDomainCert.runLocal('getResolve', {domainName: TONTestingSuite.utils.stringToBytesArray(name)});
            expect(await getAccountType(addr))
                .to
                .equal(0, 'Domain was expected not to be registered, but it is registered');
        });
        it('Check buy with wrong name', async function () {
            let wrong_name = 'test/test';
            await instantBuyDomain(secondSubDomainCert, wrong_name, duration - 2000, value);
            let addr = await secondSubDomainCert.runLocal('getResolve', {domainName: TONTestingSuite.utils.stringToBytesArray(wrong_name)});
            expect(await getAccountType(addr))
                .to
                .equal(0, 'Domain was expected not to be registered, but it is registered');
        });

    });
});


async function instantBuyDomain(contract, domainName, durationInSec, value) {
    const registerInstantNameMessage = await tonWrapper.ton.abi.encode_message_body({
        address: contract.address,
        abi: {
            type: "Contract",
            value: contract.abi,
        },
        call_set: {
            function_name: 'registerInstantName',
            input: {domainName: TONTestingSuite.utils.stringToBytesArray(domainName), durationInSec: durationInSec},
        },
        signer: {
            type: 'None',
        },
        is_internal: true,
    });

    await TestWalletContract.run('sendTransaction', {
        dest: contract.address,
        value: TONTestingSuite.utils.convertCrystal(value, 'nano'),
        bounce: true,
        flags: 0,
        payload: registerInstantNameMessage.body,
    }, null);
}

async function resolve(cert, name) {
    return await cert.runLocal('getResolve', {
        domainName: TONTestingSuite.utils.stringToBytesArray(name)
    });
}

async function getAccountType(account) {
    const {result} = await tonWrapper.ton.net.query_collection({
        collection: "accounts",
        filter: {id: {eq: account}},
        result: "acc_type",
    });
    if (!result[0]) return 0;
    return result[0].acc_type;
}
