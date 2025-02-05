require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    polygon_mainnet: {
      url: "https://polygon-rpc.com/", // שימוש ב-RPC ציבורי עבור Polygon Mainnet
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      gasPrice: 150000000000, // 150 Gwei - נבחר ידנית כדי לוודא שעסקאות עוברות מהר
    },
  },
};

// בדיקה אם ה-PRIVATE_KEY חסר והצגת הודעת שגיאה ברורה
if (!process.env.PRIVATE_KEY) {
  console.error("❌ Missing PRIVATE_KEY in .env file! Please add it and restart.");
  process.exit(1);
}













