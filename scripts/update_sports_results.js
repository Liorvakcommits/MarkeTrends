require("dotenv").config();
const axios = require("axios");
const { ethers } = require("ethers");

// 📌 הגדרות משתנים
const API_KEY = process.env.OPTIC_ODDS_API_KEY || "4cec76d7-f2a9-4977-b642-48743662d9a0"; // 🔑 API Key
const CONTRACT_ADDRESS = "0x6777767Dd2542af624b95F68D87488fB72d5AfDb"; // **כתובת חוזה SportsMarketManager**
const INFURA_PROJECT_ID = process.env.INFURA_PROJECT_ID;
const PRIVATE_KEY = process.env.PRIVATE_KEY;

// 📡 חיבור לרשת Polygon דרך Infura
const PROVIDER = new ethers.JsonRpcProvider(`https://polygon-mainnet.infura.io/v3/${INFURA_PROJECT_ID}`);
const WALLET = new ethers.Wallet(PRIVATE_KEY, PROVIDER);

// 🎯 ה-ABI של החוזה
const ABI = [
    "function fulfillGameResult(uint256 _marketId, bool outcome) public",
    "function markets(uint256) view returns (uint256 id, string name, uint256 creationTime, uint256 expirationTime, bool isResolved, bool outcome, address creator, address fpmm, bytes32 conditionId, bytes32 oracleRequestId)",
    "function nextMarketId() view returns (uint256)"
];

const CONTRACT = new ethers.Contract(CONTRACT_ADDRESS, ABI, WALLET);

async function updateResults() {
    try {
        console.log("🔍 Fetching active markets from blockchain...");

        // 📌 שליפת **רשימת השווקים הפתוחים** מהחוזה
        const marketCount = await CONTRACT.nextMarketId();
        let openMarkets = [];

        for (let i = 1; i < marketCount; i++) {
            const market = await CONTRACT.markets(i);
            if (!market.isResolved && market.expirationTime <= Math.floor(Date.now() / 1000)) {
                openMarkets.push({ id: market.id, fixture_id: market.conditionId });
            }
        }

        if (openMarkets.length === 0) {
            console.log("⚠️ אין שווקים פתוחים לעדכון.");
            return;
        }

        console.log(`📊 בודק תוצאות עבור השווקים: ${openMarkets.map(m => m.id).join(", ")}`);

        // 📌 בקשת תוצאות עבור **משחקים שהסתיימו בלבד**
        const fixtureIds = openMarkets.map(m => m.fixture_id).join(",");
        const response = await axios.get(`https://api.opticodds.com/api/v3/fixtures/results`, {
            headers: { 'X-Api-Key': API_KEY },
            params: {
                sport: "basketball", // שחק ענף ספורט לפי הצורך
                fixture_id: fixtureIds,
                status: "finished" // 🔥 מבטיחים שהמשחקים באמת הסתיימו
            }
        });

        const results = response.data.data;

        for (const game of results) {
            const { id, home_team_display, away_team_display, result } = game;

            if (!result || !result.scores) {
                console.log(`⚠️ אין תוצאה זמינה עבור שוק ${id}, מדלג...`);
                continue;
            }

            const homeScore = result.scores.home.total;
            const awayScore = result.scores.away.total;
            const outcome = homeScore > awayScore;

            console.log(`⚽ מעדכן תוצאה: ${home_team_display} vs ${away_team_display} | תוצאה: ${homeScore} - ${awayScore}`);

            // 🔥 עדכון התוצאה בחוזה
            const tx = await CONTRACT.fulfillGameResult(id, outcome);
            await tx.wait();

            console.log(`✅ Market ${id} updated successfully!`);
        }
    } catch (error) {
        console.error("❌ שגיאה בעדכון תוצאות:", error.response ? error.response.data : error);
    }
}

// 🚀 הפעלת הפונקציה
updateResults();







