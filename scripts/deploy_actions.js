const { ethers, network } = require("hardhat");
const path = require("path");
const fs = require("fs");
const axios = require("axios");

const coinGeckID = {
  56: "binancecoin",
  32520: "bitrise-token",
  311: "omax-token",
  86: "gatechain-token",
  888: "wanchain",
  66: "oec-token",
  137: "matic-network",
  97: "binancecoin",
};

(async () => {
  try {
    console.log("---------- Deploying to chain %d ----------", network.config.chainId);
    const StakingPoolActionsFactory = await ethers.getContractFactory("StakingPoolActions");
    const cgID = coinGeckID[network.config.chainId];
    const { data } = await axios.get(`https://api.coingecko.com/api/v3/simple/price?ids=${cgID}&vs_currencies=usd`);
    const valInUSD = data[cgID].usd;
    let valEther = 0.0018 / valInUSD;
    valEther = valEther.toFixed(18);

    let stakingPoolActions = await StakingPoolActionsFactory.deploy("7659574000000000");
    stakingPoolActions = await stakingPoolActions.deployed();

    console.log("Deployed to ", stakingPoolActions.address);

    const location = path.join(__dirname, "../staking_pool_actions_addresses.json");
    const fileExists = fs.existsSync(location);

    if (fileExists) {
      const contentBuf = fs.readFileSync(location);
      let contentJSON = JSON.parse(contentBuf.toString());
      contentJSON = {
        ...contentJSON,
        [network.config.chainId]: stakingPoolActions.address
      };
      fs.writeFileSync(location, JSON.stringify(contentJSON, undefined, 2));
    } else {
      fs.writeFileSync(
        location,
        JSON.stringify(
          {
            [network.config.chainId]: stakingPoolActions.address
          },
          undefined,
          2
        )
      );
    }
  } catch (error) {
    console.log(error);
  }
})();
