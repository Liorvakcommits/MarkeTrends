// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IConditionalTokens.sol";

contract FixedProductMarketMaker {
    IERC20 public collateralToken;
    IConditionalTokens public conditionalTokens;
    bytes32 public conditionId;
    uint256 public outcomeSlotCount;
    uint256 public constant MIN_INITIAL_LIQUIDITY = 10 * 10**18;

    uint256[] public outcomeBalances;
    uint256 public totalLiquidity;
    mapping(address => uint256) public userBalances;

    event FPMMFunded(address indexed funder, uint256[] amountsAdded, uint256 sharesMinted);
    event FPMMRedeem(address indexed funder, uint256 amount);
    event Buy(address indexed buyer, uint256 investmentAmount, uint256 outcomeIndex, uint256 outcomeTokensBought);
    event Sell(address indexed seller, uint256 returnAmount, uint256 outcomeIndex, uint256 outcomeTokensSold);
    event MarketResolved(uint256 winningOutcomeIndex);
    event LiquidityAdded(address indexed provider, uint256 amount);

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
    }

    function splitPosition(uint256 amount, uint256 outcomeIndex) external {
        require(amount > 0, "Must split more than 0 tokens");
        require(outcomeIndex < outcomeSlotCount, "Invalid outcome index");

        bytes32 parentCollectionId = bytes32(0);
        bytes32 collectionId = conditionalTokens.getCollectionId(parentCollectionId, conditionId, 1 << outcomeIndex);

        conditionalTokens.splitPosition(collateralToken, parentCollectionId, conditionId, new uint256[](outcomeSlotCount), amount);

        userBalances[msg.sender] += amount;
        emit Buy(msg.sender, amount, outcomeIndex, amount);
    }

    function mergePositions(uint256 amount, uint256 outcomeIndex) external {
        require(amount > 0, "Must merge more than 0 tokens");
        require(outcomeIndex < outcomeSlotCount, "Invalid outcome index");

        bytes32 parentCollectionId = bytes32(0);
        bytes32 collectionId = conditionalTokens.getCollectionId(parentCollectionId, conditionId, 1 << outcomeIndex);

        conditionalTokens.mergePositions(collateralToken, parentCollectionId, conditionId, new uint256[](outcomeSlotCount), amount);

        userBalances[msg.sender] -= amount;
        emit Sell(msg.sender, amount, outcomeIndex, amount);
    }

    function redeemPositions(uint256[] calldata indexSets) external {
        require(totalLiquidity > 0, "Market is not resolved yet");

        bytes32 parentCollectionId = bytes32(0);
        conditionalTokens.redeemPositions(collateralToken, parentCollectionId, conditionId, indexSets);

        emit MarketResolved(indexSets[0]);
    }

    function addLiquidity(uint256 amount) external {
        require(amount > 0, "Must add more than 0 tokens");
        require(collateralToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        totalLiquidity += amount;
        userBalances[msg.sender] += amount;

        emit LiquidityAdded(msg.sender, amount);
    }

    function buyTokens(uint256 amount, uint256 outcomeIndex) external {
        require(amount > 0, "Must buy more than 0 tokens");
        require(outcomeIndex < outcomeSlotCount, "Invalid outcome index");
        require(outcomeBalances[outcomeIndex] > 0, "Market is empty");

        uint256 price = (amount * 1e18) / (outcomeBalances[outcomeIndex] + 1);
        require(collateralToken.transferFrom(msg.sender, address(this), price), "Transfer failed");

        outcomeBalances[outcomeIndex] += amount;

        emit Buy(msg.sender, price, outcomeIndex, amount);
    }

    function sellTokens(uint256 amount, uint256 outcomeIndex) external {
        require(amount > 0, "Must sell more than 0 tokens");
        require(outcomeIndex < outcomeSlotCount, "Invalid outcome index");
        require(outcomeBalances[outcomeIndex] >= amount, "Not enough balance to sell");

        uint256 price = (amount * 1e18) / (outcomeBalances[outcomeIndex] + 1);
        outcomeBalances[outcomeIndex] -= amount;

        require(collateralToken.transfer(msg.sender, price), "Transfer failed");

        emit Sell(msg.sender, price, outcomeIndex, amount);
    }

    function resolveMarket(uint256 winningOutcomeIndex) external {
        require(winningOutcomeIndex < outcomeSlotCount, "Invalid winning outcome index");
        require(totalLiquidity > 0, "Market has no liquidity");

        for (uint256 i = 0; i < outcomeSlotCount; i++) {
            if (i == winningOutcomeIndex) {
                outcomeBalances[i] = totalLiquidity;
            } else {
                outcomeBalances[i] = 0;
            }
        }

        emit MarketResolved(winningOutcomeIndex);
    }
}


