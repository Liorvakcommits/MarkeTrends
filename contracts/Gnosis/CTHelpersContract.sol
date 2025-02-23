// SPDX-License-Identifier: LGPL-3.0
pragma solidity ^0.8.20;

import "./CTHelpers.sol";

contract CTHelpersContract {
    function getCollectionIdExternal(bytes32 parentCollectionId, bytes32 conditionId, uint indexSet) external pure returns (bytes32) {
        return CTHelpers.getCollectionId(parentCollectionId, conditionId, indexSet);
    }

    function getConditionIdExternal(address oracle, bytes32 questionId, uint256 outcomeSlotCount) external pure returns (bytes32) {
        return CTHelpers.getConditionId(oracle, questionId, outcomeSlotCount);
    }
}