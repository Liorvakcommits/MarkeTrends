require("dotenv").config();
const { ethers } = require("hardhat");

const MARKET_MANAGER_ADDRESS = "0xE5B21Fa58B20Edc37B27d10176f3518f423a2bD7"; // כתובת החוזה
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const INFURA_PROJECT_ID = process.env.INFURA_PROJECT_ID;

async function createMarkets() {
    const provider = new ethers.JsonRpcProvider(`https://polygon-mainnet.infura.io/v3/${INFURA_PROJECT_ID}`);
    const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
    const marketManager = new ethers.Contract(
        MARKET_MANAGER_ADDRESS,
        ["function createMarketFromOracle(string memory _name, uint256 _expirationTime, string memory gameId) public"],
        wallet
    );

    const upcomingGames = [
        { name: "Lakers vs Bulls", expiration: 1714828800, gameId: "nba-20230405-lal-chi" },
        { name: "Celtics vs Warriors", expiration: 1714832400, gameId: "nba-20230405-bos-gsw" }
    ];

    for (let game of upcomingGames) {
        console.log(`⚽ Creating market: ${game.name}`);
        const tx = await marketManager.createMarketFromOracle(game.name, game.expiration, game.gameId);
        await tx.wait();
        console.log(`✅ Market created for ${game.name}`);
    }
}

createMarkets();



