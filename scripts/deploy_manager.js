// scripts/deploy_manager.js
const hre = require("hardhat");
const fs = require("fs");

async function main() {
    console.log("Starting deployment process...");

    // ביטול מחיקת `artifacts/` כדי למנוע אובדן קובץ החוזה
    console.log("Skipping cache clean to preserve artifacts.");

    const [deployer] = await hre.ethers.getSigners();
    console.log("Deploying MarketManager with account:", deployer.address);

    // בדיקה אם `artifacts/` באמת מכיל את `MarketManager.json`
    const artifactsPath = "./artifacts/contracts/MarketManager.sol/MarketManager.json";
    if (!fs.existsSync(artifactsPath)) {
        console.error("❌ Error: MarketManager.json not found in artifacts!");
        console.error("Try running: npx hardhat compile --force");
        process.exit(1);
    }

    const MarketManager = await hre.ethers.getContractFactory("MarketManager");

    // פריסה של החוזה
    const marketManager = await MarketManager.deploy(deployer.address);

    console.log("Transaction Hash:", marketManager.deploymentTransaction().hash);
    await marketManager.waitForDeployment();

    const contractAddress = await marketManager.getAddress();
    console.log("MarketManager deployed at:", contractAddress);

    // שמירת הכתובת לקובץ כדי למנוע טעינת כתובת ישנה
    fs.writeFileSync("./deployed_address.txt", contractAddress);
    console.log("Deployment successful! Address saved to deployed_address.txt");
}

main().catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exitCode = 1;
});

