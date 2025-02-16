const { ethers } = require("hardhat");
const fs = require('fs');
const path = require('path');

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Interacting with contracts using the account:", deployer.address);

  // Load deployment addresses
  const deploymentPath = path.join(__dirname, '..', 'deployment-addresses.json');
  const deploymentAddresses = JSON.parse(fs.readFileSync(deploymentPath, 'utf8'));

  // Connect to deployed contracts
  const MarketManager = await ethers.getContractFactory("MarketManager");
  const marketManager = await MarketManager.attach(deploymentAddresses.MarketManager);

  const MarketManagerHelper = await ethers.getContractFactory("MarketManagerHelper");
  const marketManagerHelper = await MarketManagerHelper.attach(deploymentAddresses.MarketManagerHelper);

  const ConditionalTokens = await ethers.getContractFactory("ConditionalTokens");
  const conditionalTokens = await ConditionalTokens.attach(deploymentAddresses.ConditionalTokens);

  // Interact with MarketManager
  console.log("Creating a new market...");
  const marketName = "Test Market";
  const pricePerToken = ethers.utils.parseEther("0.1");
  const expirationTimestamp = Math.floor(Date.now() / 1000) + 86400; // 24 hours from now

  try {
    const tx = await marketManager.createMarket(marketName, pricePerToken, expirationTimestamp);
    const receipt = await tx.wait();
    console.log("Market created. Transaction hash:", receipt.transactionHash);

    // Get market details
    const marketId = 1; // Assuming this is the first market
    const marketDetails = await marketManager.getMarketDetails(marketId);
    console.log("Market Details:", marketDetails);

    // Buy tokens
    console.log("Buying tokens...");
    const buyAmount = ethers.utils.parseEther("1");
    const buyTx = await marketManager.buyTokens(marketId, buyAmount, true);
    const buyReceipt = await buyTx.wait();
    console.log("Tokens bought. Transaction hash:", buyReceipt.transactionHash);

    // Get market statistics
    const marketStats = await marketManagerHelper.getMarketStatistics(marketId);
    console.log("Market Statistics:", marketStats);

    // Get user trading stats
    const userStats = await marketManagerHelper.getUserTradingStats(deployer.address, marketId);
    console.log("User Trading Stats:", userStats);

    // Resolve market (only owner can do this)
    console.log("Resolving market...");
    const resolveTx = await marketManager.resolveMarket(marketId, true);
    const resolveReceipt = await resolveTx.wait();
    console.log("Market resolved. Transaction hash:", resolveReceipt.transactionHash);

    // Claim rewards
    console.log("Claiming rewards...");
    const claimTx = await marketManager.claimRewards(marketId);
    const claimReceipt = await claimTx.wait();
    console.log("Rewards claimed. Transaction hash:", claimReceipt.transactionHash);

  } catch (error) {
    console.error("Error interacting with contracts:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });






