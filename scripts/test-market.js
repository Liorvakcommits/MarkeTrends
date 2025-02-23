const { ethers } = require("hardhat");

async function main() {
    const marketManagerAddress = "0x6465fe80c3f618108183B9ebb267d6ae1b1627Af"; // עדכן לכתובת האחרונה שלך
    const MarketManager = await ethers.getContractAt("MarketManager", marketManagerAddress);

    console.log("✅ יצירת שוק...");
    let tx = await MarketManager.createMarket("Test Market", 86400);
    await tx.wait();
    console.log("✅ שוק נוצר בהצלחה!");

    console.log("✅ בדיקת FPMM קיים...");
    const market = await MarketManager.markets(1);
    if (market.fpmm === "0x0000000000000000000000000000000000000000") {
        console.log("✅ יצירת FPMM...");
        tx = await MarketManager.createFPMM(1);
        await tx.wait();
        console.log("✅ FPMM נוצר בהצלחה!");
    } else {
        console.log("⚠️ FPMM כבר קיים, אין צורך ליצור מחדש!");
    }

    console.log("✅ בדיקת הכתובת של FPMM...");
    console.log("📌 כתובת ה-FPMM:", market.fpmm);

    console.log("✅ בדיקת נזילות...");
    const FixedProductMarketMaker = await ethers.getContractAt("FixedProductMarketMaker", market.fpmm);
    const balance = await FixedProductMarketMaker.totalLiquidity();
    console.log("📌 יתרת נזילות של FPMM:", balance.toString());
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("❌ שגיאה במהלך הבדיקה:", error);
        process.exit(1);
    });
