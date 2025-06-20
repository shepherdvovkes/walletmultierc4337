// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../IEntryPoint.sol";

interface IValidationPlugin {
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash
    ) external returns (uint256);
}
