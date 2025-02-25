const hre = require("hardhat");
const fs = require("fs");
const path = require("path");
const { setAddress, updateFromTxtFile } = require("../utils/address-manager");

async function main() {
    console.log("פריסת חוזים עם החשבון:");

    const [deployer] = await hre.ethers.getSigners();
    console.log("כתובת המפיץ:", deployer.address);

    const balance = await deployer.provider.getBalance(deployer.address);
    console.log("יתרת החשבון:", hre.ethers.formatEther(balance), "ETH");

    // ✅ פריסת MarketManagerHelper
    console.log("פורס MarketManagerHelper...");
    const MarketManagerHelper = await hre.ethers.getContractFactory("MarketManagerHelper");
    const marketManagerHelper = await MarketManagerHelper.deploy();
    await marketManagerHelper.waitForDeployment();
    const helperAddress = await marketManagerHelper.getAddress();
    console.log("MarketManagerHelper נפרס בכתובת:", helperAddress);

    // ✅ פריסת CTHelpers
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

    // ✅ פריסת `ConditionalTokens`
    console.log("פורס ConditionalTokens...");
    const ConditionalTokens = await hre.ethers.getContractFactory("ConditionalTokens");
    const conditionalTokens = await ConditionalTokens.deploy();
    await conditionalTokens.waitForDeployment();
    const conditionalTokensAddress = await conditionalTokens.getAddress();
    console.log("✅ ConditionalTokens נפרס בכתובת:", conditionalTokensAddress);

    // כתובות של חוזים קיימים
    const mtcAddress = "0xDa8337dE835b0e3f35aBca046eA53508BBcB4fd0"; // כתובת ה-MTC
    const oracleAddress = "0x326C977E6efc84E512bB9C30f76E30c160eD06FB"; // כתובת ה-Oracle
    const sportsDataFeedAddress = "0x9326BFA02ADD2366b30bacB125260Af641031331"; // 🏀 Chainlink NBA Sports Data Feed

    // ✅ פריסת MarketManager
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

    // ✅ **פריסת `SportsMarketManager` עם OpticOdds API**
    console.log("פורס SportsMarketManager...");

    const chainlinkFee = hre.ethers.parseUnits("0.1", "ether");
    const opticOddsApiKey = "4cec76d7-f2a9-4977-b642-48743662d9a0"; // ✅ ה-API Key של OpticOdds

    const SportsMarketManager = await hre.ethers.getContractFactory("SportsMarketManager");
    const sportsMarketManager = await SportsMarketManager.deploy(
        mtcAddress,                   // ✅ כתובת הטוקן
        conditionalTokensAddress,      // ✅ כתובת ה-ConditionalTokens
        oracleAddress,                 // ✅ כתובת ה-Oracle
        chainlinkFee,                   // ✅ עמלת Chainlink
        "https://api.opticodds.com/v1/games",  // ✅ כתובת ה-API של OpticOdds
        opticOddsApiKey,                 // ✅ הוספת API Key
        helperAddress                     // ✅ כתובת ה-Helper
    );

    await sportsMarketManager.waitForDeployment();
    const sportsManagerAddress = await sportsMarketManager.getAddress();
    console.log("✅ SportsMarketManager נפרס בהצלחה בכתובת:", sportsManagerAddress);

    // 📌 עדכון שהשוק ייווצר אוטומטית אחרי הפריסה!
    console.log("🚀 הפעלת יצירת שווקים אוטומטיים...");
    const exec = require("child_process").exec;
    exec("node scripts/auto_create_sports_markets.js", (err, stdout, stderr) => {
        if (err) {
            console.error("❌ שגיאה בהרצת `auto_create_sports_markets.js`:", err);
            return;
        }
        console.log(stdout);
    });

    // ✅ כתיבה לקובץ txt כולל כל החוזים
    const txtContent = `MarketManager: ${managerAddress}
    SportsMarketManager: ${sportsManagerAddress}
    MarketManagerHelper: ${helperAddress}
    CTHelpers: ${ctHelpersAddress}
    CTHelpersContract: ${ctHelpersContractAddress}
    ConditionalTokens: ${conditionalTokensAddress}\n`;

    const txtPath = path.join(__dirname, "deployed_manager_addresses.txt");
    fs.writeFileSync(txtPath, txtContent);
    console.log(`📌 הכתובות נשמרו בקובץ ${txtPath}`);

    // ✅ עדכון הכתובות המרכזיות
    updateFromTxtFile(txtPath);

    console.log("🎉 הפריסה הושלמה בהצלחה!");
}

main().catch((error) => {
    console.error("❌ הפריסה נכשלה:", error);
    process.exitCode = 1;
});

