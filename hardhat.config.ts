import { config as dotenvConfig } from "dotenv";

dotenvConfig();
import "hardhat-deploy";
import "hardhat-deploy-ethers";
// TS Support
import "@nomiclabs/hardhat-ethers";
import "hardhat-contract-sizer";

import "hardhat-gas-reporter";
import "@typechain/hardhat";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-etherscan";
import "solidity-coverage";

import { NetworksUserConfig, HardhatUserConfig } from "hardhat/types";

const PRIVATE_KEY = process.env.PRIVATE_KEY || "";
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY;
const REPORT_GAS = Boolean(process.env.REPORT_GAS);

const networks: NetworksUserConfig = {
  hardhat: {},
  localhost: {},
  coverage: {
    url: "http://127.0.0.1:8555", // Coverage launches its own ganache-cli client
  },
  fuji: {
    url: `https://api.avax-test.network/ext/bc/C/rpc`,
    chainId: 43113,
    accounts: [PRIVATE_KEY],
  },
  mainnet: {
    url: `https://api.avax.network/ext/bc/C/rpc`,
    chainId: 43114,
    accounts: [PRIVATE_KEY],
  },
};

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  solidity: {
    compilers: [
      {
        version: "0.8.9",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  gasReporter: {
    currency: "EUR",
    enabled: REPORT_GAS,
    showTimeSpent: true,
  },
  networks,
  mocha: {
    timeout: 200000,
  },
  typechain: {
    outDir: "types",
    target: "ethers-v5",
  },
};

if (ETHERSCAN_API_KEY) {
  config.etherscan = {
    apiKey: ETHERSCAN_API_KEY,
  };
}

export default config;
