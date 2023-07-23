require("@nomiclabs/hardhat-ethers");
// require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-verify");
// require("@nomiclabs/hardhat-etherscan");
require("dotenv").config();

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545",
      accounts: ["0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"],
      chainId: 31337
    },
    bitgert_mainnet: {
      url: "https://rpc.icecreamswap.com",
      accounts: ["1b2639dc8ef4a32529ba762e785f5900fa1484f2e28abb494ca551ea02811c19"],
      chainId: 32520,
      gas: 8000000
    },
    okx_mainnet: {
      url: "https://exchainrpc.okex.org",
      accounts: ["bcf0b4e36ed13443445a2f062c8aee211d4a632d350fa94695de05fea9ceaad9"],
      chainId: 66
    },
    astar_mainnet: {
      url: "https://nodes.vefinetwork.org/astar",
      accounts: ["bcf0b4e36ed13443445a2f062c8aee211d4a632d350fa94695de05fea9ceaad9"],
      chainId: 592
    },
    bsc_mainnet: {
      url: "https://bsc-dataseed4.defibit.io",
      accounts: ["bcf0b4e36ed13443445a2f062c8aee211d4a632d350fa94695de05fea9ceaad9"],
      chainId: 56,
      gas: 3250000
    },
    bsc_testnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      accounts: ["bcf0b4e36ed13443445a2f062c8aee211d4a632d350fa94695de05fea9ceaad9"],
      chainId: 97
    }
  },
  etherscan: {
    apiKey: process.env.BRISE_API_KEY,
    customChains: [
      {
        network: "bitgert_mainnet",
        chainId: 32520,
        urls: {
          apiURL: "https://bitgert.getblock.io/0af6ba44-48d1-46da-b467-92c9d1ec5ed2/mainnet/",
          browserURL: "https://brisescan.com/"
        }
      }
    ]
  }
};
