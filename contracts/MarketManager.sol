// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MarketManager
 * @dev חוזה לניהול הימורים באמצעות ERC-1155 תחת מותג MarkeTrends Coins (MTC)
 */
contract MarketManager is ERC1155, Ownable {
    uint256 public nextMarketId = 1;
    mapping(uint256 => string) public marketNames;
    mapping(uint256 => uint256) public tokenPrices; // מחיר לכל הימור
    mapping(uint256 => uint256) public expirationTimestamps; // תאריך תפוגה לכל שוק
    mapping(uint256 => bool) public marketResolved; // האם השוק נסגר
    mapping(uint256 => bool) public marketOutcome; // התוצאה של השוק
    uint256 public contractBalance; // משתנה חדש שישמור על יתרת ה-MATIC בתוך החוזה

    event ContractDeployed(address indexed owner);
    event MarketCreated(uint256 indexed marketId, string marketName, uint256 initialSupply, uint256 pricePerToken, uint256 expirationTimestamp);
    event TokensPurchased(address indexed buyer, uint256 indexed marketId, uint256 amount, uint256 totalPaid, uint256 contractBalance);
    event TokensSold(address indexed seller, uint256 indexed marketId, uint256 amount, uint256 refundAmount, uint256 contractBalance);
    event MarketResolved(uint256 indexed marketId, bool outcome);
    event RewardsClaimed(address indexed user, uint256 indexed marketId, uint256 payout);
    event FundsWithdrawn(address indexed owner, uint256 amount);

  constructor(address initialOwner) 
    ERC1155("https://gateway.pinata.cloud/ipfs/bafkreigvzntdxazuivgc5rj376omfk6ahvxrfgbe6623x22elqz545c4ju/{id}.json") 
    Ownable(initialOwner) {
    emit ContractDeployed(initialOwner);
}


    /**
     * @dev פונקציה לקבלת MATIC ישירות לחוזה
     */
    receive() external payable {
        contractBalance += msg.value; // שומר את הכסף בחוזה
    }

    /**
     * @dev יצירת שוק חדש להימור
     */
    function createMarket(string memory marketName, uint256 initialSupply, uint256 pricePerToken, uint256 expirationTimestamp) public onlyOwner {
        require(bytes(marketName).length > 0, "Market name cannot be empty");
        require(initialSupply > 0, "Initial supply must be greater than 0");
        require(pricePerToken > 0, "Price per token must be greater than 0");
        require(expirationTimestamp > block.timestamp, "Expiration date must be in the future");

        marketNames[nextMarketId] = marketName;
        tokenPrices[nextMarketId] = pricePerToken;
        expirationTimestamps[nextMarketId] = expirationTimestamp;
        
        _mint(owner(), nextMarketId, initialSupply, "");

        emit MarketCreated(nextMarketId, marketName, initialSupply, pricePerToken, expirationTimestamp);
        nextMarketId++;
    }

    /**
     * @dev מחזירה את מספר השוק הבא
     */
    function getNextMarketId() public view returns (uint256) {
        return nextMarketId;
    }

    /**
     * @dev בדיקה אם שוק נסגר
     */
    function isMarketResolved(uint256 marketId) public view returns (bool) {
        return marketResolved[marketId];
    }

    /**
     * @dev קבלת פרטי שוק
     */
    function getMarketDetails(uint256 marketId) public view returns (string memory, uint256, uint256, bool, bool) {
        return (
            marketNames[marketId],
            tokenPrices[marketId],
            expirationTimestamps[marketId],
            marketResolved[marketId],
            marketOutcome[marketId]
        );
    }

    /**
     * @dev רכישת טוקן של הימור מסוים
     */
    function buyTokens(uint256 marketId, uint256 amount) public payable {
        require(balanceOf(owner(), marketId) >= amount, "Not enough tokens available");
        require(msg.value == tokenPrices[marketId] * amount, "Incorrect payment amount");
        require(!marketResolved[marketId], "Market is already resolved");

        _safeTransferFrom(owner(), msg.sender, marketId, amount, "");
        contractBalance += msg.value; // שומר את ה-MATIC בחוזה

        emit TokensPurchased(msg.sender, marketId, amount, msg.value, contractBalance);
    }

    /**
     * @dev מכירת טוקן של הימור חזרה לשוק
     */
    function sellTokens(uint256 marketId, uint256 amount) public {
        require(balanceOf(msg.sender, marketId) >= amount, "You don't own enough tokens");
        require(!marketResolved[marketId], "Market is already resolved");

        uint256 refundAmount = tokenPrices[marketId] * amount;
        require(contractBalance >= refundAmount, "Contract does not have enough funds");

        _safeTransferFrom(msg.sender, owner(), marketId, amount, "");

        contractBalance -= refundAmount; // מעדכן את יתרת החוזה
        (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
        require(success, "Failed to transfer refund");

        emit TokensSold(msg.sender, marketId, amount, refundAmount, contractBalance);
    }

    /**
     * @dev סגירת שוק לאחר תאריך תפוגה והגדרת תוצאה
     */
    function resolveMarket(uint256 marketId, bool outcome) public onlyOwner {
        require(expirationTimestamps[marketId] <= block.timestamp || msg.sender == owner(), "Market is not expired yet");
        require(!marketResolved[marketId], "Market already resolved");

        marketResolved[marketId] = true;
        marketOutcome[marketId] = outcome;

        emit MarketResolved(marketId, outcome);
    }

    /**
     * @dev משיכת רווחים לאחר סגירת השוק
     */
    function claimRewards(uint256 marketId) public {
        require(marketResolved[marketId], "Market is not resolved yet");

        uint256 userBalance = balanceOf(msg.sender, marketId);
        require(userBalance > 0, "No tokens to claim");

        uint256 totalPayout = tokenPrices[marketId] * userBalance;
        uint256 platformFee = (totalPayout * 2) / 100; // 2% עמלה
        uint256 finalPayout = totalPayout - platformFee;

        require(contractBalance >= finalPayout, "Not enough funds in contract");
        _burn(msg.sender, marketId, userBalance); // מוחק את הטוקנים של המשתמש לאחר קבלת הרווחים
        contractBalance -= totalPayout; // מעדכן את יתרת החוזה לאחר התשלום

        (bool success, ) = payable(msg.sender).call{value: finalPayout}("");
        require(success, "Failed to transfer rewards");

        (bool platformSuccess, ) = payable(owner()).call{value: platformFee}("");
        require(platformSuccess, "Platform fee transfer failed");

        emit RewardsClaimed(msg.sender, marketId, finalPayout);
    }

    /**
     * @dev מאפשר לבעלים למשוך את כל הכספים מהחוזה
     */
    function withdrawFunds() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds available");
        contractBalance = 0; // מאפס את יתרת החוזה לאחר משיכה

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdraw failed");

        emit FundsWithdrawn(owner(), balance);
    }

    /**
     * @dev קבלת יתרת החוזה
     */
   function getContractBalance() public view returns (uint256) {
    return address(this).balance; // מציג את היתרה האמיתית של החוזה
}

}

















