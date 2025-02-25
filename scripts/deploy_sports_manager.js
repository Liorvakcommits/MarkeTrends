require("dotenv").config();
const { ethers } = require("hardhat");

async function main() {
    const SportsMarketManager = await ethers.getContractFactory("SportsMarketManager");
    const sportsMarketManager = await SportsMarketManager.deploy(
        process.env.MTC_TOKEN,
        process.env.CONDITIONAL_TOKENS,
        process.env.CHAINLINK_ORACLE,
        process.env.CHAINLINK_JOB_ID,
        process.env.CHAINLINK_FEE,
        process.env.CHAINLINK_SPORTS_FEED,
        process.env.MARKET_MANAGER_HELPER
    );

    await sportsMarketManager.waitForDeployment();
    console.log("✅ SportsMarketManager deployed at:", await sportsMarketManager.getAddress());
}

main().catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exitCode = 1;
});
