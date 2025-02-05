// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IConditionalTokens {
    function prepareCondition(
        address oracle,
        bytes32 questionId,
        uint256 outcomeSlotCount
    ) external;

    // פונקציות נוספות שאתה צריך מהחוזה הישן, לדוגמה:
    // function reportPayouts(bytes32 conditionId, uint[] calldata payouts) external;
    // ...
}


