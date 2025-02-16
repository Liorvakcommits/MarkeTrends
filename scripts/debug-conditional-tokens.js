const hre = require("hardhat");
const { ethers } = hre;

async function main() {
  console.log("Hardhat Runtime Environment:", hre.network.name);
  console.log("Ethers version:", ethers.version);

  const marketManagerAddress = "0xee392918D53be2663475e3B3C63502D0f55d094f";
  console.log("Attempting to connect to MarketManager at:", marketManagerAddress);

  try {
    const MarketManagerArtifact = await hre.artifacts.readArtifact("MarketManager");
    console.log("MarketManager ABI loaded:", !!MarketManagerArtifact.abi);
    
    const marketManager = new ethers.Contract(marketManagerAddress, MarketManagerArtifact.abi, ethers.provider);
    console.log("MarketManager address:", marketManager.address);

    const owner = await marketManager.owner();
    console.log("Contract owner:", owner);

    const [signer] = await ethers.getSigners();
    console.log("Current signer:", signer.address);

    console.log("Is contract paused?", await marketManager.contractPaused());
    console.log("Is emergency lock active?", await marketManager.emergencyLock());
    console.log("Next Market ID:", (await marketManager.nextMarketId()).toString());

    const conditionalTokensAddress = await marketManager.conditionalTokens();
    console.log("ConditionalTokens address:", conditionalTokensAddress);

    console.log("Attempting to create a market...");
    const marketName = "Test Market";
    const pricePerToken = ethers.parseEther("0.1");
    const expirationTimestamp = Math.floor(Date.now() / 1000) + 3600;
    
    console.log("Market parameters:");
    console.log("- Name:", marketName);
    console.log("- Price per token:", pricePerToken.toString());
    console.log("- Expiration timestamp:", expirationTimestamp);

    const tx = await marketManager.connect(signer).createMarket(
      marketName,
      pricePerToken,
      expirationTimestamp,
      { gasLimit: 1000000 }
    );
    console.log("Transaction sent:", tx.hash);
    const receipt = await tx.wait();
    console.log("Transaction receipt:", receipt);
    console.log("Market created successfully");
  } catch (error) {
    console.error("Error:", error.message);
    if (error.transaction) {
      console.log("Failed transaction details:", error.transaction);
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });