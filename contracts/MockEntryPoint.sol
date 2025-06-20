// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IEntryPoint.sol";

contract MockEntryPoint is IEntryPoint {
    mapping(address => uint256) public deposits;
    
    event UserOperationEvent(bytes32 indexed userOpHash, address indexed sender, address indexed paymaster, uint256 nonce, bool success, uint256 actualGasCost, uint256 actualGasUsed);
    event Deposited(address indexed account, uint256 totalDeposit);
    event Withdrawn(address indexed account, address withdrawAddress, uint256 amount);
    
    function handleOps(UserOperation[] calldata ops, address payable beneficiary) external override {
        for (uint256 i = 0; i < ops.length; i++) {
            UserOperation calldata op = ops[i];
            bytes32 userOpHash = getUserOpHash(op);
            
            // In a real implementation, this would validate and execute the operation
            // For mock purposes, we'll just emit an event
            emit UserOperationEvent(userOpHash, op.sender, address(0), op.nonce, true, 0, 0);
        }
    }
    
    function depositTo(address account) external payable override {
        deposits[account] += msg.value;
        emit Deposited(account, deposits[account]);
    }
    
    function withdrawTo(address payable withdrawAddress, uint256 withdrawAmount) external override {
        require(deposits[msg.sender] >= withdrawAmount, "Insufficient deposit");
        deposits[msg.sender] -= withdrawAmount;
        withdrawAddress.transfer(withdrawAmount);
        emit Withdrawn(msg.sender, withdrawAddress, withdrawAmount);
    }
    
    function getUserOpHash(UserOperation calldata userOp) public pure override returns (bytes32) {
        return keccak256(abi.encode(
            userOp.sender,
            userOp.nonce,
            keccak256(userOp.initCode),
            keccak256(userOp.callData),
            userOp.callGasLimit,
            userOp.verificationGasLimit,
            userOp.preVerificationGas,
            userOp.maxFeePerGas,
            userOp.maxPriorityFeePerGas,
            keccak256(userOp.paymasterAndData)
        ));
    }
    
    function getDepositInfo(address account) external view returns (uint256) {
        return deposits[account];
    }
}
