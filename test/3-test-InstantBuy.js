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
        let name = 'asd';

        before(async function () {
            await instantBuyDomain(rootCert, name, 10000, '23');
            firstSubDomainAddr = await rootCert.runLocal('getResolve', {domainName: TONTestingSuite.utils.stringToBytesArray(name)});
            firstSubDomainCert = copyContract(NicContract);
            firstSubDomainCert.address = firstSubDomainAddr;
            logger.log(`Subdomain Certificate: ${firstSubDomainAddr}`);
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
