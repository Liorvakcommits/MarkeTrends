const hre = require("hardhat");
const fs = require('fs');
const path = require('path');
const { setAddress, updateFromTxtFile } = require('../utils/address-manager');

async function main() {
    console.log("פריסת חוזים עם החשבון:");

    const [deployer] = await hre.ethers.getSigners();
    console.log("כתובת המפיץ:", deployer.address);

    const balance = await deployer.provider.getBalance(deployer.address);
    console.log("יתרת החשבון:", hre.ethers.formatEther(balance), "ETH");

    // פריסת MarketManagerHelper
    console.log("פורס MarketManagerHelper...");
    const MarketManagerHelper = await hre.ethers.getContractFactory("MarketManagerHelper");
    const marketManagerHelper = await MarketManagerHelper.deploy();
    await marketManagerHelper.waitForDeployment();
    const helperAddress = await marketManagerHelper.getAddress();
    console.log("MarketManagerHelper נפרס בכתובת:", helperAddress);

    // כתובות של חוזים קיימים
    const mtcAddress = "0xDa8337dE835b0e3f35aBca046eA53508BBcB4fd0"; // כתובת ה-MTC
    const conditionalTokensAddress = "0xA8Cc778572FD192d1aCDDc520C144db7a6ae1547"; // כתובת ה-ConditionalTokens
    const oracleAddress = "0x326C977E6efc84E512bB9C30f76E30c160eD06FB"; // כתובת ה-Oracle

    // פריסת MarketManager
    console.log("פורס MarketManager...");
    const MarketManager = await hre.ethers.getContractFactory("MarketManager");
    const marketManager = await MarketManager.deploy(
        mtcAddress,
        conditionalTokensAddress,
        oracleAddress,
        helperAddress
    );

    await marketManager.waitForDeployment();
    const managerAddress = await marketManager.getAddress();
    console.log("MarketManager נפרס בכתובת:", managerAddress);

    // כתיבה לקובץ txt
    const txtContent = `MarketManager: ${managerAddress}\nMarketManagerHelper: ${helperAddress}\n`;
    const txtPath = path.join(__dirname, 'deployed_manager_addresses.txt');
    fs.writeFileSync(txtPath, txtContent);
    console.log(`הכתובות נשמרו בקובץ ${txtPath}`);

    // עדכון הכתובות המרכזיות
    updateFromTxtFile(txtPath);

    console.log("🎉 הפריסה הושלמה בהצלחה!");
}

main().catch((error) => {
    console.error("❌ הפריסה נכשלה:", error);
    process.exitCode = 1;
});