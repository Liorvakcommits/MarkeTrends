// SPDX-License-Identifier: LGPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // ✅ הוספת ה- import

library CTHelpers {
    /// @dev Constructs a condition ID from an oracle, a question ID, and the outcome slot count for the question.
    function getConditionId(address oracle, bytes32 questionId, uint outcomeSlotCount) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(oracle, questionId, outcomeSlotCount));
    }

    /// @dev Constructs an outcome collection ID from a parent collection and an outcome collection.
    function getCollectionId(bytes32 parentCollectionId, bytes32 conditionId, uint indexSet) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(parentCollectionId, conditionId, indexSet));
    }

    /// @dev Constructs a position ID from a collateral token and an outcome collection. These IDs are used as the ERC-1155 ID for this contract.
    function getPositionId(address collateralToken, bytes32 collectionId) internal pure returns (uint) {
        return uint(keccak256(abi.encodePacked(collateralToken, collectionId)));
    }

    function getPayoutNumeratorKey(bytes32 conditionId, uint outcomeIndex) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(conditionId, outcomeIndex));
    }

    function getFullIndexSet(uint outcomeSlotCount) internal pure returns (uint) {
        return (1 << outcomeSlotCount) - 1;
    }

    function isPartition(uint[] memory partition, uint fullIndexSet) internal pure returns (bool) {
        uint bitUnion;
        for (uint i = 0; i < partition.length; i++) {
            uint indexSet = partition[i];
            bitUnion |= indexSet;
        }
        return bitUnion == fullIndexSet;
    }

    function getOutcomeSlotCount(bytes32 conditionId) internal pure returns (uint) {
        return uint(uint8(conditionId[0]));
    }
}

