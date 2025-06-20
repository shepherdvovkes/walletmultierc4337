// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ModularSmartAccount.sol";

contract SmartAccountFactory {
    IEntryPoint public immutable entryPoint;
    
    event AccountCreated(address indexed account, address indexed owner, uint256 salt);
    
    constructor(IEntryPoint _entryPoint) {
        entryPoint = _entryPoint;
    }
    
    function createAccount(address owner, uint256 salt) external returns (address) {
        address account = address(new ModularSmartAccount{salt: bytes32(salt)}(entryPoint));
        emit AccountCreated(account, owner, salt);
        return account;
    }
    
    function getAddress(address owner, uint256 salt) external view returns (address) {
        return address(uint160(uint(keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this),
            salt,
            keccak256(abi.encodePacked(type(ModularSmartAccount).creationCode, abi.encode(entryPoint)))
        )))));
    }
}
