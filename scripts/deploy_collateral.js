const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
    console.log("🚀 פריסת טוקן הבטוחה (Collateral Token)...");

    const [deployer] = await hre.ethers.getSigners();
    console.log("🔹 כתובת המפיץ:", deployer.address);

    // יצירת חוזה ERC20 לטוקן הבטוחה
    const CollateralToken = await hre.ethers.getContractFactory("CollateralToken");
    const initialSupply = hre.ethers.parseUnits("10000000", 18); // 10 מיליון טוקנים
    const collateralToken = await CollateralToken.deploy("Collateral Token", "CLT", initialSupply);

    await collateralToken.waitForDeployment();

    const collateralTokenAddress = await collateralToken.getAddress();
    console.log("✅ טוקן הבטוחה נפרס בכתובת:", collateralTokenAddress);

    // שמירת הכתובת בקובץ
    const deploymentPath = path.join(__dirname, "deployed_addresses.json");
    let deployedAddresses = {};
    if (fs.existsSync(deploymentPath)) {
        deployedAddresses = JSON.parse(fs.readFileSync(deploymentPath, "utf8"));
    }
    deployedAddresses.CollateralToken = collateralTokenAddress;
    fs.writeFileSync(deploymentPath, JSON.stringify(deployedAddresses, null, 2));
    console.log("📄 כתובת טוקן הבטוחה נשמרה בקובץ deployed_addresses.json");

    // עדכון ה-MarketManager עם כתובת טוקן הבטוחה
    if (deployedAddresses.MarketManager) {
        const MarketManager = await hre.ethers.getContractFactory("MarketManager");
        const marketManager = MarketManager.attach(deployedAddresses.MarketManager);
        await marketManager.updateCollateralToken(collateralTokenAddress);
        console.log("✅ כתובת טוקן הבטוחה עודכנה ב-MarketManager");
    } else {
        console.warn("⚠️ כתובת ה-MarketManager לא נמצאה. יש לעדכן את טוקן הבטוחה ידנית.");
    }

    // הדפסת מידע נוסף
    console.log("\n📊 מידע נוסף על טוקן הבטוחה:");
    console.log(`🔸 שם: ${await collateralToken.name()}`);
    console.log(`🔸 סימול: ${await collateralToken.symbol()}`);
    console.log(`🔸 מספר עשרונות: ${await collateralToken.decimals()}`);
    console.log(`🔸 סך האספקה ההתחלתית: ${hre.ethers.formatUnits(initialSupply, 18)} CLT`);
}

main().catch((error) => {
    console.error("❌ הפריסה נכשלה:", error);
    process.exitCode = 1;
});
