const TONTestingSuite = require("ton-testing-suite");

async function setupKeyPairs(keysAmount = 100) {
    if (!this.config.seed) {
        const entropy = `0x${TONTestingSuite.utils.genHexString(32)}`;

        const {
            phrase,
        } = await this.ton.crypto.mnemonic_from_entropy({
            entropy,
            word_count: 12,
        });

        this.config.seed = phrase;
    }

    const keysHDPaths = [...Array(keysAmount).keys()].map(i => `m/44'/396'/0'/0/${i}`);
    let keys = Array();
    for (const x of keysHDPaths) {
        let k = await this.ton.crypto.mnemonic_derive_sign_keys({
            dictionary: 1,
            wordCount: 12,
            phrase: this.config.seed,
            path: x,
        })
        keys.push(k);
    }
    this.keys = keys;
}

module.exports = {
  setupKeyPairs: setupKeyPairs
};
