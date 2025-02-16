// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IConditionalTokens.sol";

contract FixedProductMarketMaker {
    IERC20 public collateralToken;
    IConditionalTokens public conditionalTokens;
    bytes32 public conditionId;
    uint256 public outcomeSlotCount;

    uint256[] public outcomeBalances;
    uint256 public totalLiquidity;

    event FPMMFunded(address indexed funder, uint256[] amountsAdded, uint256 sharesMinted);
    event FPMMRedeem(address indexed funder, uint256 amount);
    event Buy(address indexed buyer, uint256 investmentAmount, uint256 outcomeIndex, uint256 outcomeTokensBought);
    event Sell(address indexed seller, uint256 returnAmount, uint256 outcomeIndex, uint256 outcomeTokensSold);

    constructor(
        IERC20 _collateralToken,
        IConditionalTokens _conditionalTokens,
        bytes32 _conditionId,
        uint256 _outcomeSlotCount
    ) {
        require(address(_collateralToken) != address(0), "Invalid collateral token");
        require(address(_conditionalTokens) != address(0), "Invalid conditional tokens");
        require(_outcomeSlotCount > 1, "There must be at least two outcome slots");
        
        collateralToken = _collateralToken;
        conditionalTokens = _conditionalTokens;
        conditionId = _conditionId;
        outcomeSlotCount = _outcomeSlotCount;
        outcomeBalances = new uint256[](_outcomeSlotCount);
    }
    
    function addLiquidity(uint256 addedFunds) external {
        require(addedFunds > 0, "Added funds must be greater than 0");
        require(collateralToken.transferFrom(msg.sender, address(this), addedFunds), "Transfer failed");

        uint256 mintAmount;
        if (totalLiquidity == 0) {
            mintAmount = addedFunds;
            for (uint256 i = 0; i < outcomeSlotCount; i++) {
                outcomeBalances[i] = addedFunds;
            }
        } else {
            uint256 contractBalance = collateralToken.balanceOf(address(this));
            mintAmount = (addedFunds * totalLiquidity) / (contractBalance - addedFunds);
            for (uint256 i = 0; i < outcomeSlotCount; i++) {
                uint256 proportion = (outcomeBalances[i] * addedFunds) / (contractBalance - addedFunds);
                outcomeBalances[i] += proportion;
            }
        }

        totalLiquidity += mintAmount;

        uint256[] memory amountsAdded = new uint256[](outcomeSlotCount);
        for (uint256 i = 0; i < outcomeSlotCount; i++) {
            amountsAdded[i] = addedFunds / outcomeSlotCount;
        }

        emit FPMMFunded(msg.sender, amountsAdded, mintAmount);
    }


    function removeLiquidity(uint256 shares) external {

        uint256 collateralAmount = (shares * collateralToken.balanceOf(address(this))) / totalLiquidity;
        totalLiquidity = totalLiquidity - shares;

        for (uint256 i = 0; i < outcomeSlotCount; i++) {
            outcomeBalances[i] = outcomeBalances[i] - collateralAmount;
        }


        emit FPMMRedeem(msg.sender, collateralAmount);
    }

    function buy(uint256 investmentAmount, uint256 outcomeIndex) external {

        uint256 outcomeTokensToBuy = calcBuyAmount(investmentAmount, outcomeIndex);


        outcomeBalances[outcomeIndex] = outcomeBalances[outcomeIndex] + investmentAmount;

        conditionalTokens.splitPosition(
            collateralToken,
            bytes32(0),
            conditionId,
            partition(outcomeIndex),
            outcomeTokensToBuy
        );

        conditionalTokens.safeTransferFrom(address(this), msg.sender, getPositionId(outcomeIndex), outcomeTokensToBuy, "");

        emit Buy(msg.sender, investmentAmount, outcomeIndex, outcomeTokensToBuy);
    }

    function sell(uint256 returnAmount, uint256 outcomeIndex) external {

        uint256 outcomeTokensToSell = calcSellAmount(returnAmount, outcomeIndex);

        conditionalTokens.safeTransferFrom(msg.sender, address(this), getPositionId(outcomeIndex), outcomeTokensToSell, "");

        conditionalTokens.mergePositions(
            collateralToken,
            bytes32(0),
            conditionId,
            partition(outcomeIndex),
            outcomeTokensToSell
        );

        outcomeBalances[outcomeIndex] = outcomeBalances[outcomeIndex] - returnAmount;


        emit Sell(msg.sender, returnAmount, outcomeIndex, outcomeTokensToSell);
    }

    function calcBuyAmount(uint256 investmentAmount, uint256 outcomeIndex) public view returns (uint256) {
        uint256 b = outcomeBalances[outcomeIndex];
        uint256 bPrime = b + investmentAmount;
        uint256 result = (totalLiquidity * (bPrime - b)) / b;
        return result;
    }

    function calcSellAmount(uint256 returnAmount, uint256 outcomeIndex) public view returns (uint256) {
        uint256 b = outcomeBalances[outcomeIndex];
        uint256 bPrime = b - returnAmount;
        uint256 result = (totalLiquidity * (b - bPrime)) / b;
        return result;
    }

    function getPositionId(uint256 outcomeIndex) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(collateralToken, conditionId, 1 << outcomeIndex)));
    }

function partition(uint256 outcomeIndex) internal pure returns (uint256[] memory) {
    uint256[] memory partitionResult = new uint256[](1);
    partitionResult[0] = 1 << outcomeIndex;
    return partitionResult;
}


}
