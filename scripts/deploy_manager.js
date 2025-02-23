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

    // פריסת CTHelpers
    console.log("פורס CTHelpers...");
    const CTHelpers = await hre.ethers.getContractFactory("CTHelpers");
    const ctHelpers = await CTHelpers.deploy();
    await ctHelpers.waitForDeployment();
    const ctHelpersAddress = await ctHelpers.getAddress();
    console.log("CTHelpers נפרס בכתובת:", ctHelpersAddress);

    console.log("פורס CTHelpersContract...");
    const CTHelpersContract = await hre.ethers.getContractFactory("CTHelpersContract");
    const ctHelpersContract = await CTHelpersContract.deploy();
    await ctHelpersContract.waitForDeployment();
    const ctHelpersContractAddress = await ctHelpersContract.getAddress();
    console.log("CTHelpersContract נפרס בכתובת:", ctHelpersContractAddress);

    // ✅ **פריסת `ConditionalTokens` מחדש**
    console.log("פורס ConditionalTokens...");
    const ConditionalTokens = await hre.ethers.getContractFactory("ConditionalTokens");
    const conditionalTokens = await ConditionalTokens.deploy();
    await conditionalTokens.waitForDeployment();
    const conditionalTokensAddress = await conditionalTokens.getAddress();
    console.log("✅ ConditionalTokens נפרס בכתובת:", conditionalTokensAddress);

    // כתובות של חוזים קיימים
    const mtcAddress = "0xDa8337dE835b0e3f35aBca046eA53508BBcB4fd0"; // כתובת ה-MTC
    const oracleAddress = "0x326C977E6efc84E512bB9C30f76E30c160eD06FB"; // כתובת ה-Oracle

    // פריסת MarketManager עם `ConditionalTokens` החדש
    console.log("פורס MarketManager...");
    const MarketManager = await hre.ethers.getContractFactory("MarketManager");
    const marketManager = await MarketManager.deploy(
        mtcAddress,
        conditionalTokensAddress, // ✅ עדכון לכתובת החדשה
        oracleAddress,
        helperAddress
    );

    await marketManager.waitForDeployment();
    const managerAddress = await marketManager.getAddress();
    console.log("MarketManager נפרס בכתובת:", managerAddress);

    // יצירת שוק חדש
    console.log("✅ יצירת שוק...");
    let tx = await marketManager.createMarket("Auto Test Market", 86400);
    await tx.wait();
    console.log("✅ שוק נוצר בהצלחה!");

    // בדיקת הכתובת של FPMM
    let fpmmAddress;
    const market = await marketManager.markets(1);
    if (market.fpmm === "0x0000000000000000000000000000000000000000") {
        console.log("✅ יצירת FPMM בפריסה...");
        tx = await marketManager.createFPMM(1);
        await tx.wait();
        fpmmAddress = (await marketManager.markets(1)).fpmm;
        console.log("✅ FPMM נוצר בהצלחה בפריסה!");
    } else {
        fpmmAddress = market.fpmm;
        console.log("⚠️ FPMM כבר קיים, אין צורך ליצור מחדש!");
    }

    // כתיבה לקובץ txt כולל ה-FPMM וה-CTHelpers
    const txtContent = `MarketManager: ${managerAddress}
    MarketManagerHelper: ${helperAddress}
    FixedProductMarketMaker: ${fpmmAddress}
    CTHelpers: ${ctHelpersAddress}
    CTHelpersContract: ${ctHelpersContractAddress}
    ConditionalTokens: ${conditionalTokensAddress}\n`; // ✅ הוספת `ConditionalTokens`
    
    const txtPath = path.join(__dirname, 'deployed_manager_addresses.txt');
    fs.writeFileSync(txtPath, txtContent);
    console.log(`📌 הכתובות נשמרו בקובץ ${txtPath}`);

    // עדכון הכתובות המרכזיות
    updateFromTxtFile(txtPath);

    console.log("🎉 הפריסה הושלמה בהצלחה!");
}

main().catch((error) => {
    console.error("❌ הפריסה נכשלה:", error);
    process.exitCode = 1;
});
