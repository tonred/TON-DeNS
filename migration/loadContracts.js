const TONTestingSuite = require("ton-testing-suite");


async function loadContract(tonWrapper, name, address) {
    await tonWrapper._setupTonClient()
    return await TONTestingSuite.requireContract(tonWrapper, name, address, process.env.ARTIFACTS_PATH);
}

module.exports = {
    loadDeNSRootContract: async function (tw) {
        return await loadContract(tw, process.env.DNS_ROOT_CONTRACT);
    },
    loadDeNSCertContract: async function (tw) {
        return await loadContract(tw, process.env.DNS_NIC_CONTRACT);
    },
    loadDeNSAuctionContract: async function (tw) {
        return await loadContract(tw, process.env.DNS_AUCTION_CONTRACT);
    },
    loadDeNSDebotContract: async function (tw) {
        return await loadContract(tw, process.env.DNS_DEBOT_CONTRACT);
    },
    loadParticipantStorageContract: async function (tw) {
        return await loadContract(tw, process.env.DNS_PARTICIPANT_STORAGE_CONTRACT);
    },
    loadTestWalletContract: async function (tw) {
        return await loadContract(tw, process.env.TEST_WALLET_CONTRACT);
    },
    loadTestRootContract: async function (tw) {
        return await loadContract(tw, process.env.TEST_DNS_ROOT_CONTRACT);
    },
    loadTestNicContract: async function (tw) {
        return await loadContract(tw, process.env.TEST_DNS_NIC_CONTRACT);
    },
    loadTestAuctionContract: async function (tw) {
        return await loadContract(tw, process.env.TEST_DNS_AUCTION_CONTRACT);
    },
}
