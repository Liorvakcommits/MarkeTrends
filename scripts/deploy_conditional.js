const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
    console.log("🚀 פריסת ConditionalTokens (Gnosis)...");

    const [deployer] = await hre.ethers.getSigners();
    console.log("🔹 כתובת המפיץ:", deployer.address);

    const ConditionalTokens = await hre.ethers.getContractFactory("ConditionalTokens");
    const conditionalTokens = await ConditionalTokens.deploy();
    await conditionalTokens.waitForDeployment();

    const conditionalTokensAddress = await conditionalTokens.getAddress();
    console.log("✅ ConditionalTokens נפרס בכתובת:", conditionalTokensAddress);

    if (!conditionalTokensAddress) {
        console.error("❌ שגיאה: כתובת ה-ConditionalTokens אינה מוגדרת!");
        process.exit(1);
    }

    const deploymentPath = path.join(__dirname, "deployed_addresses.json");
    let deployedAddresses = {};
    if (fs.existsSync(deploymentPath)) {
        deployedAddresses = JSON.parse(fs.readFileSync(deploymentPath, "utf8"));
    }
    deployedAddresses.ConditionalTokens = conditionalTokensAddress;
    fs.writeFileSync(deploymentPath, JSON.stringify(deployedAddresses, null, 2));
    console.log("📄 כתובת ConditionalTokens נשמרה בקובץ deployed_addresses.json");
}

main().catch((error) => {
    console.error("❌ הפריסה נכשלה:", error);
    process.exitCode = 1;
});

