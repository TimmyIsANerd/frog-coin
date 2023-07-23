const { ethers } = require("hardhat");

(async () => {
  try {
    const TokenFactory = await ethers.getContractFactory("BEFE");
    console.log("Deploying...");
    let token = await TokenFactory.deploy(
      "BEFE",
      "BEFE",
      ethers.utils.parseUnits("100000000", 18),
      "0xF62bf9E069B08a6e479208A36aDFE668701BCD94",
      15
    );
    token = await token.deployed();
    console.log(token.address);
  } catch (error) {
    console.log(error);
  }
})();
