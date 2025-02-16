// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MTC
 * @dev טוקן ERC20 עבור MarkeTrends Coins עם יכולת הטבעה נוספת על ידי הבעלים.
 */
contract MTC is ERC20, Ownable {
    /**
     * @dev הבנאי מקבל:
     * - כמות ראשונית להנפקה
     */
    constructor(uint256 initialSupply) ERC20("MarkeTrends Coins", "MTC") Ownable() {
        _mint(msg.sender, initialSupply);
    }

    /**
     * @dev מאפשר לבעלים להטביע טוקנים נוספים.
     * @param to הכתובת שאליה יוטבעו הטוקנים החדשים
     * @param amount כמות הטוקנים להטבעה
     */
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}

