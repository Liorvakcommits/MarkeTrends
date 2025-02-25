require("dotenv").config();
const { ethers } = require("hardhat");
const axios = require("axios");
const fs = require('fs');
const path = require('path');

// קונפיגורציה
const SPORTS_MARKET_MANAGER_ADDRESS = "0x6777767Dd2542af624b95F68D87488fB72d5AfDb";
const OPTIC_ODDS_API_KEY = "4cec76d7-f2a9-4977-b642-48743662d9a0";
const BASE_URL = "https://api.opticodds.com/api/v3";
const BATCH_SIZE = 5;
const BATCH_DELAY = 30000; // 30 שניות בין באצ'ים
const PROCESSED_GAMES_FILE = path.join(__dirname, '..', 'processed_games.json');

// פונקציות עזר
function getHeaders() {
    return {
        'x-api-key': OPTIC_ODDS_API_KEY,
        'Accept': 'application/json',
        'Content-Type': 'application/json'
    };
}

// ניהול משחקים שטופלו
class ProcessedGamesManager {
    constructor(filePath) {
        this.filePath = filePath;
        this.processedGames = new Set();
        this.loadProcessedGames();
    }

    loadProcessedGames() {
        try {
            if (fs.existsSync(this.filePath)) {
                const data = fs.readFileSync(this.filePath);
                this.processedGames = new Set(JSON.parse(data));
                console.log(`נטענו ${this.processedGames.size} משחקים שכבר טופלו`);
                console.log('רשימת המשחקים:', [...this.processedGames]);
            } else {
                console.log("הקובץ לא קיים, מתחיל רשימה חדשה של משחקים מטופלים");
                fs.writeFileSync(this.filePath, JSON.stringify([]));
            }
        } catch (error) {
            console.error("שגיאה בטעינת משחקים מטופלים:", error);
            console.log("מתחיל רשימה חדשה של משחקים מטופלים");
            this.processedGames = new Set();
        }
    }

    isProcessed(gameId) {
        // וידוא שהמזהה תמיד עם התחילית nba:
        const withPrefix = gameId.startsWith('nba:') ? gameId : `nba:${gameId}`;
        const isProcessed = this.processedGames.has(withPrefix);
        console.log(`בדיקת משחק ${withPrefix}: ${isProcessed ? 'כבר טופל' : 'טרם טופל'}`);
        return isProcessed;
    }

    markAsProcessed(gameId) {
        // וידוא שהמזהה תמיד עם התחילית nba:
        const withPrefix = gameId.startsWith('nba:') ? gameId : `nba:${gameId}`;
        this.processedGames.add(withPrefix);
        const gamesArray = [...this.processedGames];
        fs.writeFileSync(this.filePath, JSON.stringify(gamesArray, null, 2));
        console.log(`נשמר משחק ${withPrefix}`);
        console.log('רשימת משחקים מעודכנת:', gamesArray);
    }
}

async function fetchUpcomingBasketballGames() {
    try {
        console.log("מקבל משחקי כדורסל עתידיים...");

        const response = await axios.get(`${BASE_URL}/fixtures`, {
            params: {
                sport: 'basketball',
                league: 'nba'
            },
            headers: getHeaders()
        });

        if (response.data && response.data.data) {
            const allGames = response.data.data;
            const now = new Date();
            
            const futureGames = allGames.filter(game => {
                const gameDate = new Date(game.start_date);
                return gameDate > now;
            }).map(game => {
                // וידוא שה-ID תמיד בפורמט הנכון
                const gameId = game.id.startsWith('nba:') ? game.id : `nba:${game.id}`;
                return {
                    id: gameId,
                    start_date: game.start_date,
                    home_team: {
                        name: game.home_team_display || (game.home_competitors[0]?.name || 'TBD'),
                        id: game.home_competitors[0]?.id || '',
                    },
                    away_team: {
                        name: game.away_team_display || (game.away_competitors[0]?.name || 'TBD'),
                        id: game.away_competitors[0]?.id || '',
                    },
                    venue: game.venue_name,
                    broadcast: game.broadcast
                };
            });

            console.log(`נמצאו ${futureGames.length} משחקים עתידיים`);
            futureGames.forEach(game => {
                console.log(`- משחק ${game.id}: ${game.home_team.name} vs ${game.away_team.name}`);
            });
            
            return futureGames;
        }
        
        return [];
    } catch (error) {
        console.error("שגיאה בקבלת משחקים:", error.message);
        if (error.response) {
            console.error("תגובת API:", error.response.data);
        }
        throw error;
    }
}

async function processGameBatch(batch, marketManager, processedGamesManager) {
    console.log(`מעבד קבוצה של ${batch.length} משחקים...`);

    for (const game of batch) {
        try {
            if (processedGamesManager.isProcessed(game.id)) {
                console.log(`משחק ${game.id} כבר טופל, מדלג...`);
                continue;
            }

            const gameName = `NBA: ${game.home_team.name} vs ${game.away_team.name}`;
            const expirationTime = Math.floor(new Date(game.start_date).getTime() / 1000);

            console.log(`
                יוצר שוק חדש:
                משחק: ${gameName}
                תאריך: ${new Date(game.start_date).toLocaleString()}
                מזהה: ${game.id}
                אצטדיון: ${game.venue || 'לא ידוע'}
                שידור: ${game.broadcast || 'לא ידוע'}
            `);

            const tx = await marketManager.createMarketFromOracle(
                gameName,
                expirationTime,
                game.id // שימוש במזהה המלא כולל התחילית nba:
            );
            
            await tx.wait();
            console.log(`✅ נוצר שוק חדש! Hash: ${tx.hash}`);
            
            processedGamesManager.markAsProcessed(game.id);
            
            // המתנה קצרה בין משחקים באותו באץ'
            await new Promise(resolve => setTimeout(resolve, 2000));

        } catch (error) {
            console.error(`❌ שגיאה ביצירת שוק למשחק ${game.id}:`, error.message);
            if (error.transaction) {
                console.error("פרטי טרנזקציה:", {
                    hash: error.transaction.hash,
                    from: error.transaction.from,
                    to: error.transaction.to,
                    data: error.transaction.data
                });
            }
        }
    }
}

async function createSportsMarkets() {
    console.log('נתיב לקובץ משחקים מעובדים:', PROCESSED_GAMES_FILE);
    const processedGamesManager = new ProcessedGamesManager(PROCESSED_GAMES_FILE);

    try {
        const games = await fetchUpcomingBasketballGames();
        
        if (games.length === 0) {
            console.log("לא נמצאו משחקים עתידיים");
            return;
        }

        const provider = new ethers.JsonRpcProvider(`https://polygon-mainnet.infura.io/v3/${process.env.INFURA_PROJECT_ID}`);
        const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
        const marketManager = new ethers.Contract(
            SPORTS_MARKET_MANAGER_ADDRESS,
            ["function createMarketFromOracle(string memory _name, uint256 _expirationTime, string memory gameId) public"],
            wallet
        );

        // עיבוד באצ'ים
        for (let i = 0; i < games.length; i += BATCH_SIZE) {
            const batch = games.slice(i, i + BATCH_SIZE);
            console.log(`מעבד באץ' ${Math.floor(i/BATCH_SIZE) + 1} מתוך ${Math.ceil(games.length/BATCH_SIZE)}`);
            
            await processGameBatch(batch, marketManager, processedGamesManager);
            
            // המתנה בין באצ'ים
            if (i + BATCH_SIZE < games.length) {
                console.log(`ממתין ${BATCH_DELAY/1000} שניות לפני הבאץ' הבא...`);
                await new Promise(resolve => setTimeout(resolve, BATCH_DELAY));
            }
        }

        console.log("✅ כל המשחקים טופלו בהצלחה!");

    } catch (error) {
        console.error("❌ שגיאה כללית:", error.message);
        if (error.code) {
            console.error("קוד שגיאה:", error.code);
        }
    }
}

// הרצת הסקריפט
createSportsMarkets().catch((error) => {
    console.error("❌ שגיאה בהרצת הסקריפט:", error);
    process.exit(1);
});
