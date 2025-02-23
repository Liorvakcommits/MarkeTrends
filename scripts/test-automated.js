const { ethers } = require("hardhat");

async function main() {
    const marketManagerAddress = "0xcDe0b9a951399961638B040B07c23225ecf69465"; // כתובת MarketManager העדכנית שלך
    const MarketManager = await ethers.getContractAt("MarketManager", marketManagerAddress);

    console.log("✅ יצירת שוק חדש...");
    let tx = await MarketManager.createMarket("Automated Test Market", 86400);
    await tx.wait();
    console.log("✅ שוק נוצר בהצלחה!");

    // קבלת כתובת ה-FPMM
    const market = await MarketManager.markets(1);
    const fpmmAddress = market.fpmm;

    console.log("✅ כתובת FPMM:", fpmmAddress);

    const FPMM = await ethers.getContractAt("FixedProductMarketMaker", fpmmAddress);
    const MTC = await ethers.getContractAt("IERC20", "0xDa8337dE835b0e3f35aBca046eA53508BBcB4fd0");

    // אישור והוספת נזילות
    console.log("✅ הוספת נזילות ראשונית...");
    await MTC.approve(FPMM.target, ethers.parseEther("10"));
    tx = await FPMM.addLiquidity(ethers.parseEther("10"));
    await tx.wait();
    console.log("✅ נזילות נוספה בהצלחה!");

    // רכישת טוקנים
    console.log("✅ רכישת טוקנים...");
    await MTC.approve(FPMM.target, ethers.parseEther("1"));
    tx = await FPMM.buyTokens(ethers.parseEther("1"), 0);
    await tx.wait();
    console.log("✅ טוקנים נרכשו בהצלחה!");

    // מכירת טוקנים
    console.log("✅ מכירת טוקנים...");
    tx = await FPMM.sellTokens(ethers.parseEther("0.5"), 0);
    await tx.wait();
    console.log("✅ טוקנים נמכרו בהצלחה!");

    // סגירת השוק
    console.log("✅ סגירת השוק...");
    tx = await FPMM.resolveMarket(0);
    await tx.wait();
    console.log("✅ השוק נסגר בהצלחה!");

    console.log("🎉 כל הבדיקות האוטומטיות עברו בהצלחה!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("❌ שגיאה במהלך הבדיקות האוטומטיות:", error);
        process.exit(1);
    });
