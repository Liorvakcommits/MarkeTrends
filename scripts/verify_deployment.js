const hre = require("hardhat");
const { getAddress } = require('../utils/address-manager');

async function main() {
  const marketManagerAddress = getAddress('MarketManager');
  const helperAddress = getAddress('MarketManagerHelper');

  console.log("בודק את MarketManager בכתובת:", marketManagerAddress);
  const MarketManager = await hre.ethers.getContractFactory("MarketManager");
  const marketManager = await MarketManager.attach(marketManagerAddress);

  console.log("בודק את MarketManagerHelper בכתובת:", helperAddress);
  const MarketManagerHelper = await hre.ethers.getContractFactory("MarketManagerHelper");
  const helper = await MarketManagerHelper.attach(helperAddress);

  // בדיקת פונקציה בסיסית ב-MarketManager
  const nextMarketId = await marketManager.nextMarketId();
  console.log("nextMarketId:", nextMarketId.toString());

  // בדיקת פונקציה בסיסית ב-MarketManagerHelper
  const helperResult = await helper.uint2str(123);
  console.log("helper.uint2str(123):", helperResult);

  console.log("בדיקת הפריסה הושלמה בהצלחה!");
}

main().catch((error) => {
  console.error("שגיאה בבדיקת הפריסה:", error);
  process.exitCode = 1;
});