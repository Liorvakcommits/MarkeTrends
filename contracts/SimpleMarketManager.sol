// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleMarketManager {
    struct Market {
        uint256 id;
        string name;
        uint256 creationTime;
        uint256 expirationTime;  
    }

    mapping(uint256 => Market) public markets;
    uint256 public nextMarketId;

    event MarketCreated(uint256 indexed marketId, string name, uint256 creationTime, uint256 expirationTime);
    event DebugCreateMarket(string step, string name, uint256 duration, uint256 timestamp);
    event DebugTimeValues(uint256 blockTimestamp, uint256 creationTime, uint256 expirationTime);

    constructor() {
        nextMarketId = 1;
    }

    function createMarket(string memory _name, uint256 _duration) external {
        emit DebugCreateMarket("Start", _name, _duration, block.timestamp);
        
        require(_duration > 0, "Invalid duration"); // בדיקה אם הערך תקין

        uint256 marketId = nextMarketId++;
        uint256 expirationTime = block.timestamp + _duration;

        // פלט Debug כדי לוודא שהזמנים נכונים
        emit DebugTimeValues(block.timestamp, block.timestamp, expirationTime);

        markets[marketId] = Market({
            id: marketId,
            name: _name,
            creationTime: block.timestamp,
            expirationTime: expirationTime
        });

        emit MarketCreated(marketId, _name, block.timestamp, expirationTime);
    }

    function getMarketInfo(uint256 _marketId) external view returns (
        string memory name,
        uint256 creationTime,
        uint256 expirationTime
    ) {
        Market storage market = markets[_marketId];
        return (
            market.name,
            market.creationTime,
            market.expirationTime
        );
    }

    function getAllMarkets() external view returns (Market[] memory) {
        Market[] memory allMarkets = new Market[](nextMarketId - 1);
        for (uint256 i = 1; i < nextMarketId; i++) {
            allMarkets[i - 1] = markets[i];
        }
        return allMarkets;
    }

    // פונקציה לשליטה בזמן בסביבת Hardhat
    function setNextBlockTimestamp(uint256 _timestamp) external {
        require(_timestamp > block.timestamp, "Timestamp must be in the future");
        assembly {
            mstore(0x40, _timestamp)
        }
    }
}
