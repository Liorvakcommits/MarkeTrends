require('dotenv').config();
const axios = require('axios');

// 📌 הגדרות משתנים
const API_KEY = process.env.OPTIC_ODDS_API_KEY || "4cec76d7-f2a9-4977-b642-48743662d9a0"; // 🔑 ה-API Key
const SPORT = "basketball"; // ⚽ שנה את זה בהתאם לענף הספורט שלך
const LEAGUE = "nba"; // 🏆 ליגה ספציפית (אפשר לשנות בהתאם)

async function fetchFixtureId() {
    try {
        console.log("🔍 Fetching fixture_id from OpticOdds...");

        // 📡 משיכת רשימת המשחקים הפעילים בלבד
        const response = await axios.get(`https://api.opticodds.com/api/v3/fixtures/active?sport=${SPORT}&league=${LEAGUE}`, {
            headers: { "X-Api-Key": API_KEY }
        });

        const games = response.data.data;

        if (!games || games.length === 0) {
            console.log("⚠️ לא נמצאו משחקים פעילים בליגה זו.");
            return;
        }

        for (const game of games) {
            console.log(`📌 fixture_id: ${game.id} | משחק: ${game.home_team_display} vs ${game.away_team_display}`);
        }
    } catch (error) {
        console.error("❌ שגיאה במשיכת fixture_id:", error.response ? error.response.data : error);
    }
}

// 🚀 הפעלת הפונקציה
fetchFixtureId();

