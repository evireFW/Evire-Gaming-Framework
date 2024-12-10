
import { HardhatUserConfig } from "hardhat/config";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-solhint";
import "@openzeppelin/hardhat-upgrades";

const config: HardhatUserConfig = {
    solidity: {
        version: "0.8.17",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200,
            },
        },
    },
    networks: {
        hardhat: {
            forking: {
                url: process.env.MAINNET_FORK_URL || "",
                blockNumber: parseInt(process.env.FORK_BLOCK || "0"),
            },
        },
        localhost: {
            url: "http://127.0.0.1:8545",
            accounts: process.env.LOCAL_ACCOUNTS?.split(",") || [],
        },
        evireTestnet: {
            url: process.env.EVIRE_TESTNET_URL || "",
            accounts: process.env.TESTNET_ACCOUNTS?.split(",") || [],
            chainId: 9999,
        },
        evireMainnet: {
            url: process.env.EVIRE_MAINNET_URL || "",
            accounts: process.env.MAINNET_ACCOUNTS?.split(",") || [],
            chainId: 10000,
        },
    },
    etherscan: {
        apiKey: process.env.ETHERSCAN_API_KEY || "",
    },
    mocha: {
        timeout: 200000,
    },
};

export default config;
