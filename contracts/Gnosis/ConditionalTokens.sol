// SPDX-License-Identifier: LGPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // ✅ הוספת התמיכה ב-IERC20
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "./CTHelpers.sol";
import "../IConditionalTokens.sol";

contract ConditionalTokens is ERC1155, IConditionalTokens {
    using CTHelpers for bytes32;
    using SafeCast for uint256;

    mapping(address => uint256) public totalBalances;
    mapping(bytes32 => uint256) public outcomeSlotCounts;
    mapping(bytes32 => address) public payoutNumerators;
    mapping(bytes32 => uint256[]) public payoutDenominator;

    constructor() ERC1155("") {}

    function prepareCondition(address oracle, bytes32 questionId, uint256 outcomeSlotCount) external override {
        outcomeSlotCounts[questionId] = outcomeSlotCount;
        emit ConditionPreparation(questionId, oracle, questionId, outcomeSlotCount);
    }

    function reportPayouts(bytes32 questionId, uint256[] calldata payouts) external override {
        payoutDenominator[questionId] = payouts;
        emit ConditionResolution(questionId, msg.sender, questionId, outcomeSlotCounts[questionId], payouts);
    }

    function splitPosition(
        IERC20 collateralToken,
        bytes32 parentCollectionId,
        bytes32 conditionId,
        uint256[] calldata partition,
        uint256 amount
    ) external override {

        uint256 parentPositionId = CTHelpers.getPositionId(address(collateralToken), parentCollectionId);

        if (parentCollectionId == bytes32(0)) {
            totalBalances[address(collateralToken)] += amount;
        } else {
            _burn(msg.sender, parentPositionId, amount);
        }

        for (uint256 i = 0; i < partition.length; i++) {
            bytes32 collectionId = CTHelpers.getCollectionId(parentCollectionId, conditionId, partition[i]);
            uint256 positionId = CTHelpers.getPositionId(address(collateralToken), collectionId);

            _mint(msg.sender, positionId, amount, "");
        }

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
            uint256 collectionId = uint256(CTHelpers.getCollectionId(parentCollectionId, conditionId, partition[0])); // ✅ תיקון collectionId
            uint256 positionId = CTHelpers.getPositionId(address(collateralToken), bytes32(collectionId)); // ✅ הגדרת positionId לפני השימוש
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

        uint256 balance = balanceOf(msg.sender, CTHelpers.getPositionId(address(collateralToken), parentCollectionId));

        _burn(msg.sender, CTHelpers.getPositionId(address(collateralToken), parentCollectionId), balance);

        emit PayoutRedemption(msg.sender, collateralToken, parentCollectionId, conditionId, indexSets, balance);
    }

    function getOutcomeSlotCount(bytes32 conditionId) external view override returns (uint256) {
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
}
