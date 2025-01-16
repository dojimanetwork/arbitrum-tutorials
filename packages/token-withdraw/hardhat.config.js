require('@nomiclabs/hardhat-ethers')
const { hardhatConfig } = require('arb-shared-dependencies')

module.exports = {
    hardhatConfig,
    solidity: {
        compilers: [
            {
                version: '0.8.19',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                    viaIR: true,
                },
            },
        ],
    },
}
