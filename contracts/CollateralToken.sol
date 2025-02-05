// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TrendsCoins
 * @dev טוקן ERC20 שמאפשר לבעלים לעדכן את השם והסימבול.
 */
contract CollateralToken is ERC20, Ownable {
    string private _customName;
    string private _customSymbol;

    /**
     * @dev הבנאי מקבל:
     * - שם הטוקן (ERC20)
     * - הסימבול (ERC20)
     * - כתובת הבעלים (Ownable)
     * - כמות ראשונית להנפקה
     */
    constructor(
        string memory name_,
        string memory symbol_,
        address owner_,
        uint256 initialSupply
    )
        ERC20(name_, symbol_)
        Ownable(owner_)
    {
        _customName = name_;
        _customSymbol = symbol_;
        _mint(owner_, initialSupply * 10**decimals());
    }

    /**
     * @dev מאפשר לבעלים לעדכן את שם הטוקן.
     */
    function setTokenName(string memory newName) public onlyOwner {
        _customName = newName;
    }

    /**
     * @dev מאפשר לבעלים לעדכן את סימבול הטוקן.
     */
    function setTokenSymbol(string memory newSymbol) public onlyOwner {
        _customSymbol = newSymbol;
    }

    /**
     * @dev החזרת שם הטוקן.
     */
    function name() public view override returns (string memory) {
        return _customName;
    }

    /**
     * @dev החזרת הסימבול של הטוקן.
     */
    function symbol() public view override returns (string memory) {
        return _customSymbol;
    }
}

