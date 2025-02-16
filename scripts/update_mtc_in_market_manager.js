const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  const deploymentPath = path.join(__dirname, "deployed_addresses.json");
  const deployedAddresses = JSON.parse(fs.readFileSync(deploymentPath, "utf8"));

  const marketManagerAddress = "0xCC834dE1483e18b079A7E3b8C28fA8B883E2a8AC";
  const newMTCAddress = deployedAddresses.MTC;

  console.log("בדיקת כתובת ה-MTC ב-MarketManager...");
  console.log("כתובת ה-MarketManager:", marketManagerAddress);
  console.log("כתובת ה-MTC החדשה:", newMTCAddress);

  const MarketManager = await hre.ethers.getContractFactory("MarketManager");
  const marketManager = await MarketManager.attach(marketManagerAddress);

  try {
    const currentMTCAddress = await marketManager.mtcToken();
    console.log("כתובת ה-MTC הנוכחית ב-MarketManager:", currentMTCAddress);

    if (currentMTCAddress.toLowerCase() === newMTCAddress.toLowerCase()) {
      console.log("✅ כתובת ה-MTC תואמת את הכתובת החדשה");
    } else {
      console.log("❗ כתובת ה-MTC שונה מהכתובת החדשה");
      console.log("שים לב: אין אפשרות לעדכן את כתובת ה-MTC בחוזה הקיים.");
      console.log("אם נדרש שינוי, יש לשקול פריסה מחדש של MarketManager עם הכתובת החדשה.");
    }
  } catch (error) {
    console.error("❌ שגיאה בקריאת כתובת ה-MTC:", error.message);
  }
}

main().catch((error) => {
  console.error("❌ הבדיקה נכשלה:", error);
  process.exitCode = 1;
});