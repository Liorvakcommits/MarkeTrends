// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MarketManager
 * @dev חוזה לניהול הימורים באמצעות ERC-1155 תחת מותג MarkeTrends Coins (MTC)
 */
contract MarketManager is ERC1155, Ownable {
    uint256 public nextMarketId = 1; // מזהה השוק הבא
    mapping(uint256 => string) public marketNames; // שם השוק לפי מזהה
    mapping(uint256 => uint256) public tokenPrices; // מחיר לכל הימור
    mapping(uint256 => uint256) public expirationTimestamps; // תאריך תפוגה לכל שוק
    mapping(uint256 => bool) public marketResolved; // האם השוק נסגר
    mapping(uint256 => bool) public marketOutcome; // תוצאה של השוק (נכון / לא נכון)
    uint256 public contractBalance; // יתרת ה-MATIC בתוך החוזה
    uint256 public feesCollected; // סכום העמלות שנאסף מהמשתמשים

    /// @notice אירועים שיפעילו לוגים בפלטפורמה
    event ContractDeployed(address indexed owner);
    event MarketCreated(uint256 indexed marketId, string marketName, uint256 initialSupply, uint256 pricePerToken, uint256 expirationTimestamp);
    event TokensPurchased(address indexed buyer, uint256 indexed marketId, uint256 amount, uint256 totalPaid, uint256 contractBalance);
    event TokensSold(address indexed seller, uint256 indexed marketId, uint256 amount, uint256 refundAmount, uint256 contractBalance);
    event MarketResolved(uint256 indexed marketId, bool outcome);
    event RewardsClaimed(address indexed user, uint256 indexed marketId, uint256 payout);
    event FundsWithdrawn(address indexed owner, uint256 amount);
    event FeesWithdrawn(address indexed owner, uint256 amount);
    event FundsAdded(address indexed sender, uint256 amount);

    /**
     * @dev קונסטרקטור שמאתחל את החוזה
     */
    constructor(address initialOwner) 
        ERC1155("https://gateway.pinata.cloud/ipfs/bafkreigvzntdxazuivgc5rj376omfk6ahvxrfgbe6623x22elqz545c4ju/{id}.json") 
        Ownable(initialOwner) {
        emit ContractDeployed(initialOwner);
    }

    /**
     * @dev פונקציה לקבלת MATIC ישירות לחוזה
     */
    receive() external payable {
        contractBalance += msg.value; // שומר את הכסף בתוך החוזה
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

        uint256 ownerTokenBalance = balanceOf(owner(), nextMarketId);
        require(ownerTokenBalance == initialSupply, "Token minting failed!");

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
    uint256 public houseFeePercentage = 5; // 5% מהכסף נשאר בחוזה למימון הזוכים

  function buyTokens(uint256 marketId, uint256 amount) public payable {
    require(balanceOf(owner(), marketId) >= amount, "Not enough tokens available");
    require(msg.value == tokenPrices[marketId] * amount, "Incorrect payment amount");
    require(!marketResolved[marketId], "Market is already resolved");

    _safeTransferFrom(owner(), msg.sender, marketId, amount, "");

    uint256 fee = (msg.value * houseFeePercentage) / 100;
    uint256 netAmount = msg.value - fee;

    contractBalance += netAmount; // לוודא שהכסף מצטבר בחוזה!
    (bool success, ) = payable(owner()).call{value: fee}(""); // 5% הולך למערכת
    require(success, "House fee transfer failed");

    emit TokensPurchased(msg.sender, marketId, amount, msg.value, contractBalance);
}


    /**
     * @dev משיכת העמלות שנאספו מהעסקאות
     */
    function withdrawFees() public onlyOwner {
        require(feesCollected > 0, "No fees to withdraw");

        uint256 amount = feesCollected;
        feesCollected = 0;

        (bool success, ) = payable(owner()).call{value: amount}("");
        require(success, "Withdraw failed");

        emit FeesWithdrawn(owner(), amount);
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
 * המשתמש יכול למשוך את הכספים המגיעים לו בהתאם לכמות הטוקנים שהוא מחזיק בשוק סגור
 */
function claimRewards(uint256 marketId) public {
    require(marketResolved[marketId], "Market is not resolved yet");

    uint256 userBalance = balanceOf(msg.sender, marketId);
    require(userBalance > 0, "No tokens to claim");

    uint256 totalPayout = tokenPrices[marketId] * userBalance;
    uint256 platformFee = (totalPayout * 2) / 100;
    uint256 finalPayout = totalPayout - platformFee;

    // בדיקה כמה כסף יש בפועל בחוזה
    uint256 maxPayout = address(this).balance < finalPayout ? address(this).balance : finalPayout;
    require(maxPayout > 0, "No funds available for claim");

    // שריפת הטוקנים של המשתמש כי הוא קיבל את התשלום
    _burn(msg.sender, marketId, userBalance);

    // עדכון יתרת החוזה
    contractBalance -= maxPayout;

    // העברת הכסף למשתמש
    (bool success, ) = payable(msg.sender).call{value: maxPayout}("");
    require(success, "Partial payout failed");

    // העברת העמלה לפלטפורמה
    if (address(this).balance >= platformFee) {
        (bool platformSuccess, ) = payable(owner()).call{value: platformFee}("");
        require(platformSuccess, "Platform fee transfer failed");
    }

    emit RewardsClaimed(msg.sender, marketId, maxPayout);
}



function fundContract() public payable {
    require(msg.value > 0, "Must send some MATIC");
    contractBalance += msg.value;
    emit FundsAdded(msg.sender, msg.value);
}

mapping(address => uint256) public pendingRewards; // חוב למשתמשים

function retryClaim() public {
    uint256 pendingAmount = pendingRewards[msg.sender];
    require(pendingAmount > 0, "No pending rewards");

    uint256 availableFunds = address(this).balance;
    uint256 payout = availableFunds >= pendingAmount ? pendingAmount : availableFunds;

    require(payout > 0, "No funds available for payout");

    // עדכון יתרת החוב
    pendingRewards[msg.sender] -= payout;
    contractBalance -= payout;

    (bool success, ) = payable(msg.sender).call{value: payout}("");
    require(success, "Retry payout failed");

    emit RewardsClaimed(msg.sender, 0, payout);
}


   /**
 * @dev קבלת יתרת החוזה מהבלוקצ'יין
 */
function getContractBalance() public view returns (uint256) {
    return address(this).balance; // מציג את היתרה האמיתית של החוזה בבלוקצ'יין
}

}


















