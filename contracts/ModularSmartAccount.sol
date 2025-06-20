// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IEntryPoint.sol";
import "./interfaces/IPlugin.sol";
import "./interfaces/IValidationPlugin.sol";

// Modular Smart Account (ERC-4337 + ERC-6900)
contract ModularSmartAccount {
    IEntryPoint public immutable entryPoint;
    uint256 public nonce;
    
    mapping(bytes4 => address) public plugins;
    
    event PluginInstalled(bytes4 indexed selector, address indexed plugin);
    event PluginUninstalled(bytes4 indexed selector);
    event Received(address indexed sender, uint256 amount);
    
    modifier onlyEntryPoint() {
        require(msg.sender == address(entryPoint), "Only EntryPoint");
        _;
    }
    
    modifier onlySelf() {
        require(msg.sender == address(this), "Only self");
        _;
    }
    
    constructor(IEntryPoint _entryPoint) {
        entryPoint = _entryPoint;
    }
    
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
    
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external onlyEntryPoint returns (uint256 validationData) {
        // Check if we need to pay missing funds
        if (missingAccountFunds > 0) {
            (bool success,) = payable(msg.sender).call{value: missingAccountFunds}("");
            require(success, "Failed to pay missing funds");
        }
        
        // Get the validation plugin
        bytes4 selector = bytes4(userOp.callData[:4]);
        address plugin = plugins[selector];
        
        if (plugin != address(0)) {
            return IValidationPlugin(plugin).validateUserOp(userOp, userOpHash);
        }
        
        // Default validation (single owner)
        return _validateSignature(userOp, userOpHash);
    }
    
    function _validateSignature(
        UserOperation calldata userOp,
        bytes32 userOpHash
    ) internal view returns (uint256) {
        // Simple signature validation for MVP
        bytes32 hash = keccak256(abi.encodePacked(userOpHash, address(this), block.chainid));
        address signer = recoverSigner(hash, userOp.signature);
        
        // For MVP, we'll accept any valid signature
        if (signer != address(0)) {
            return 0; // Valid
        }
        return 1; // Invalid
    }
    
    function recoverSigner(bytes32 hash, bytes memory signature) internal pure returns (address) {
        if (signature.length != 65) {
            return address(0);
        }
        
        bytes32 r;
        bytes32 s;
        uint8 v;
        
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }
        
        if (v < 27) {
            v += 27;
        }
        
        if (v != 27 && v != 28) {
            return address(0);
        }
        
        return ecrecover(hash, v, r, s);
    }
    
    function installPlugin(bytes4 selector, address plugin, bytes calldata data) external onlySelf {
        require(plugins[selector] == address(0), "Plugin already installed");
        require(plugin != address(0), "Invalid plugin address");
        
        plugins[selector] = plugin;
        IPlugin(plugin).onInstall(data);
        
        emit PluginInstalled(selector, plugin);
    }
    
    function uninstallPlugin(bytes4 selector, bytes calldata data) external onlySelf {
        address plugin = plugins[selector];
        require(plugin != address(0), "Plugin not installed");
        
        delete plugins[selector];
        IPlugin(plugin).onUninstall(data);
        
        emit PluginUninstalled(selector);
    }
    
    function execute(address to, uint256 value, bytes calldata data) external {
        require(msg.sender == address(this) || msg.sender == address(entryPoint), "Unauthorized");
        
        (bool success, bytes memory result) = to.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }
    
    function executeBatch(
        address[] calldata to,
        uint256[] calldata value,
        bytes[] calldata data
    ) external {
        require(msg.sender == address(this) || msg.sender == address(entryPoint), "Unauthorized");
        require(to.length == value.length && to.length == data.length, "Mismatched arrays");
        
        for (uint256 i = 0; i < to.length; i++) {
            (bool success, bytes memory result) = to[i].call{value: value[i]}(data[i]);
            if (!success) {
                assembly {
                    revert(add(result, 32), mload(result))
                }
            }
        }
    }
}
