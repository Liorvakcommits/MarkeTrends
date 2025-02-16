const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
    console.log("🚀 פריסת MarketManagerHelper...");

    const [deployer] = await hre.ethers.getSigners();
    console.log("🔹 כתובת המפיץ:", deployer.address);

    const MarketManagerHelper = await hre.ethers.getContractFactory("MarketManagerHelper");
    const marketManagerHelper = await MarketManagerHelper.deploy(deployer.address);

    await marketManagerHelper.waitForDeployment();

    const helperAddress = await marketManagerHelper.getAddress();
    console.log("✅ MarketManagerHelper נפרס בכתובת:", helperAddress);

    const deploymentPath = path.join(__dirname, "deployed_addresses.json");
    let deployedAddresses = {};
    if (fs.existsSync(deploymentPath)) {
        deployedAddresses = JSON.parse(fs.readFileSync(deploymentPath, "utf8"));
    }
    deployedAddresses.MarketManagerHelper = helperAddress;
    fs.writeFileSync(deploymentPath, JSON.stringify(deployedAddresses, null, 2));
    console.log("📄 כתובת MarketManagerHelper נשמרה בקובץ deployed_addresses.json");

    // עדכון כתובת ה-MarketManager בחוזה ה-Helper
    const marketManagerAddress = deployedAddresses.MarketManager;
    if (marketManagerAddress) {
        await marketManagerHelper.setMarketManager(marketManagerAddress);
        console.log("✅ כתובת ה-MarketManager עודכנה ב-MarketManagerHelper");
    } else {
        console.warn("⚠️ כתובת ה-MarketManager לא נמצאה. יש לעדכן אותה מאוחר יותר.");
    }
}

main().catch((error) => {
    console.error("❌ הפריסה נכשלה:", error);
    process.exitCode = 1;
});
