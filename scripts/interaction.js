// scripts/interaction.js
const { ethers } = require("hardhat");
const fs = require("fs");

async function main() {
    const contractAddress = fs.readFileSync("./deployed_address.txt", "utf8").trim();
    const [deployer] = await ethers.getSigners();
    console.log("Deployer address:", deployer.address);

    const marketManager = await ethers.getContractAt("MarketManager", contractAddress);
    console.log("Connected to MarketManager at:", contractAddress);

    const owner = await marketManager.owner();
    console.log("Contract owner:", owner);

    const nextMarketId = await marketManager.getNextMarketId();
    console.log("Next Market ID:", nextMarketId.toString());

    console.log("Creating new market...");
    let expirationTimestamp = Math.floor(Date.now() / 1000) + (7 * 24 * 60 * 60);
    let tx = await marketManager.createMarket("Football Predictions", 1000, ethers.parseEther("0.1"), expirationTimestamp);
    await tx.wait();
    console.log("New market created!");

    const price = await marketManager.tokenPrices(1);
    console.log("Token price for Market ID 1:", ethers.formatEther(price), "MATIC");

    console.log("Checking if market is resolved before buying...");
    const isResolvedBeforeBuy = await marketManager.isMarketResolved(1);

    if (!isResolvedBeforeBuy) {
        console.log("Buying 10 tokens...");
        tx = await marketManager.buyTokens(1, 10, { value: ethers.parseEther("1") });
        await tx.wait();
        console.log("Successfully purchased 10 tokens!");
    } else {
        console.log("Market is already resolved. Skipping buyTokens().");
    }

    const balance = await marketManager.balanceOf(deployer.address, 1);
    console.log("Your token balance for Market ID 1:", balance.toString());

    const contractBalance = await marketManager.getContractBalance();
    console.log("Contract balance:", ethers.formatEther(contractBalance), "MATIC");

    console.log("Selling 5 tokens...");
    tx = await marketManager.sellTokens(1, 5);
    await tx.wait();
    console.log("Successfully sold 5 tokens!");

    console.log("Checking if market is resolved...");
    const isResolved = await marketManager.isMarketResolved(1);
    console.log("Market resolved status:", isResolved);

    if (!isResolved) {
        console.log("Resolving market...");
        tx = await marketManager.resolveMarket(1, true);
        await tx.wait();
        console.log("Market resolved as YES!");
    }

    console.log("Fetching market details...");
    const marketDetails = await marketManager.getMarketDetails(1);
    console.log("Market details:", marketDetails);

    console.log("Claiming rewards...");
    tx = await marketManager.claimRewards(1);
    await tx.wait();
    console.log("Rewards claimed successfully!");

    console.log("Withdrawing contract funds...");
    tx = await marketManager.withdrawFunds();
    await tx.wait();
    console.log("Funds withdrawn successfully!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("Error during interaction:", error);
        process.exit(1);
    });







