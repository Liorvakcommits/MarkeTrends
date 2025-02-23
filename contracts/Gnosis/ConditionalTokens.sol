// SPDX-License-Identifier: LGPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "./CTHelpers.sol";
import "../IConditionalTokens.sol";

contract ConditionalTokens is ERC1155, IConditionalTokens, ERC1155Holder {
    using CTHelpers for bytes32;
    using SafeCast for uint256;

    mapping(address => uint256) public totalBalances;
    mapping(bytes32 => uint256) public outcomeSlotCounts;
    mapping(bytes32 => address) public payoutNumerators;
    mapping(bytes32 => uint256[]) public payoutDenominator;

    constructor() ERC1155("") {}

    // ✅ תיקון בעיית `supportsInterface`
    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, ERC1155Receiver, IERC165) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function prepareCondition(address oracle, bytes32 questionId, uint256 outcomeSlotCount) external override {
        require(outcomeSlotCount > 1, "Must have at least two outcomes");

        bytes32 conditionId = CTHelpers.getConditionId(oracle, questionId, outcomeSlotCount);
        require(conditionId != bytes32(0), "Invalid conditionId");
        require(outcomeSlotCounts[conditionId] == 0, "Condition already prepared!");

        outcomeSlotCounts[conditionId] = outcomeSlotCount;
        require(outcomeSlotCounts[conditionId] > 0, "OutcomeSlotCount was not saved!");

        emit ConditionPreparation(conditionId, oracle, questionId, outcomeSlotCount);
    }

    function splitPosition(
        IERC20 collateralToken,
        bytes32 parentCollectionId,
        bytes32 conditionId,
        uint256[] calldata partition,
        uint256 amount
    ) external override {
        require(amount > 0, "Amount must be greater than zero");
        require(partition.length > 1, "Must split into at least two positions");

        uint256 parentPositionId = CTHelpers.getPositionId(address(collateralToken), parentCollectionId);

        if (parentCollectionId == bytes32(0)) {
            require(collateralToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
            totalBalances[address(collateralToken)] += amount;
        } else {
            require(balanceOf(msg.sender, parentPositionId) >= amount, "Insufficient parent position balance");
            _burn(msg.sender, parentPositionId, amount);
        }

        uint256 totalMinted = 0;
        for (uint256 i = 0; i < partition.length; i++) {
            bytes32 collectionId = CTHelpers.getCollectionId(parentCollectionId, conditionId, partition[i]); 
            uint256 positionId = CTHelpers.getPositionId(address(collateralToken), collectionId);

            uint256 mintedAmount = amount / partition.length;
            _mint(msg.sender, positionId, mintedAmount, "");
            totalMinted += mintedAmount;

            require(balanceOf(msg.sender, positionId) >= mintedAmount, "Minting failed - no tokens received!");
        }

        require(totalMinted == amount, "Minted amount mismatch");
        emit PositionSplit(msg.sender, collateralToken, parentCollectionId, conditionId, partition, amount);
    }

    function mergePositions(
        IERC20 collateralToken,
        bytes32 parentCollectionId,
        bytes32 conditionId,
        uint256[] calldata partition,
        uint256 amount
    ) external override {
        uint256 parentPositionId = CTHelpers.getPositionId(address(collateralToken), parentCollectionId);

        for (uint256 i = 0; i < partition.length; i++) {
            bytes32 collectionId = CTHelpers.getCollectionId(parentCollectionId, conditionId, partition[i]);
            uint256 positionId = CTHelpers.getPositionId(address(collateralToken), collectionId);

            _burn(msg.sender, positionId, amount);
        }

        if (parentCollectionId == bytes32(0)) {
            totalBalances[address(collateralToken)] -= amount;
        } else {
            uint256 collectionId = uint256(CTHelpers.getCollectionId(parentCollectionId, conditionId, partition[0]));
            uint256 positionId = CTHelpers.getPositionId(address(collateralToken), bytes32(collectionId));
            _mint(msg.sender, positionId, amount, "");
        }

        emit PositionsMerge(msg.sender, collateralToken, parentCollectionId, conditionId, partition, amount);
    }

function redeemPositions(
    IERC20 collateralToken,
    bytes32 parentCollectionId,
    bytes32 conditionId,
    uint256[] calldata indexSets
) external override {
    uint256 positionId = CTHelpers.getPositionId(address(collateralToken), parentCollectionId);
    uint256 userBalance = balanceOf(msg.sender, positionId);
    
    require(userBalance > 0, "No tokens to redeem");

    // 🔹 מחיקת הפוזיציות של המשתמש
    _burn(msg.sender, positionId, userBalance);

    // 🔹 בדיקה אם יש מספיק יתרת MTC בחוזה לשחרור
    uint256 contractBalance = collateralToken.balanceOf(address(this));
    require(contractBalance >= userBalance, "Insufficient contract balance");

    // 🔹 שחרור הכסף מהחוזה למשתמש
    require(collateralToken.transfer(msg.sender, userBalance), "Transfer failed");

    emit PayoutRedemption(msg.sender, collateralToken, parentCollectionId, conditionId, indexSets, userBalance);
}



    function getOutcomeSlotCount(bytes32 conditionId) external view override returns (uint256) {
        require(outcomeSlotCounts[conditionId] > 0, "Condition ID does not exist");
        return outcomeSlotCounts[conditionId];
    }

    function debugOutcomeSlot(bytes32 conditionId) external view returns (uint256) {
        return outcomeSlotCounts[conditionId];
    }

    function getConditionId(address oracle, bytes32 questionId, uint256 outcomeSlotCount) external pure override returns (bytes32) {
        return CTHelpers.getConditionId(oracle, questionId, outcomeSlotCount);
    }

    function getCollectionId(bytes32 parentCollectionId, bytes32 conditionId, uint256 indexSet) external pure override returns (bytes32) {
        return CTHelpers.getCollectionId(parentCollectionId, conditionId, indexSet);
    }

    function getPositionId(IERC20 collateralToken, bytes32 collectionId) external pure override returns (uint256) {
        return CTHelpers.getPositionId(address(collateralToken), collectionId);
    }

    function reportPayouts(bytes32 questionId, uint256[] calldata payouts) external override {
        require(outcomeSlotCounts[questionId] > 0, "Condition ID does not exist");
        require(payouts.length == outcomeSlotCounts[questionId], "Invalid payouts length");

        payoutDenominator[questionId] = payouts;

        emit ConditionResolution(questionId, msg.sender, questionId, outcomeSlotCounts[questionId], payouts);
    }

function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public pure override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public pure override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}
