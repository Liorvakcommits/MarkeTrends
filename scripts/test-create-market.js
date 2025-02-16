const hre = require("hardhat");
const { ethers } = require("ethers");

console.log("Hardhat version:", require("hardhat/package.json").version);
console.log("Ethers version:", require("ethers/package.json").version);

async function testCreateMarket() {
  await hre.run('compile');

  const [deployer] = await hre.ethers.getSigners();
  console.log("Interacting with contracts with the account:", deployer.address);

  const MarketManager = await hre.ethers.getContractFactory("MarketManager");
  const marketManager = await MarketManager.attach("0xee392918D53be2663475e3B3C63502D0f55d094f");

  const marketName = "Test Market";
  const pricePerToken = ethers.utils.parseEther("0.1");
  const expirationTimestamp = Math.floor(Date.now() / 1000) + 86400;

  console.log("Creating market...");
  console.log("Market Name:", marketName);
  console.log("Price Per Token:", pricePerToken.toString());
  console.log("Expiration Timestamp:", expirationTimestamp);
  
  try {
    const tx = await marketManager.createMarket(marketName, pricePerToken, expirationTimestamp);
    console.log("Transaction sent. Waiting for confirmation...");
    const receipt = await tx.wait();
    console.log("Transaction confirmed. Transaction hash:", receipt.transactionHash);

    console.log("Parsing logs...");
    for (const log of receipt.logs) {
      try {
        const parsedLog = MarketManager.interface.parseLog(log);
        console.log(`Event: ${parsedLog.name}`);
        console.log(`Args:`, parsedLog.args);
      } catch (error) {
        console.log("Could not parse log:", log);
      }
    }
  } catch (error) {
    console.error("Error creating market:", error);
    console.error("Error details:", error.message);
    if (error.reason) {
      console.error("Error reason:", error.reason);
    }
  }
}

testCreateMarket()
  .then(() => process.exit(0))
  .catch(error => {
    console.error("Unhandled error:", error);
    process.exit(1);
  });