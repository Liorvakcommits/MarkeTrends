const { ethers } = require("hardhat");

async function main() {
  console.log("=== Deploying ConditionalTokens (Gnosis) ===");
  // יוצרים factory עבור חוזה ConditionalTokens
  const ConditionalTokensFactory = await ethers.getContractFactory("ConditionalTokens");
  // פורסים
  const conditionalTokens = await ConditionalTokensFactory.deploy();
  await conditionalTokens.deployed();
  console.log("ConditionalTokens deployed at:", conditionalTokens.address);

  console.log("=== Deploying MarketManager ===");
  // כאן נניח שיש לנו כתובת collateralToken מוכנה
  const collateralTokenAddress = "0x0000000000000000000000000000000000000000"; 
  // החלף בכתובת ERC20 אמיתית אם יש לך

  const MarketManagerFactory = await ethers.getContractFactory("MarketManager");
  const manager = await MarketManagerFactory.deploy(
    conditionalTokens.address,
    collateralTokenAddress
  );
  await manager.deployed();
  console.log("MarketManager deployed at:", manager.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
