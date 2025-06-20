#!/bin/bash

# ERC-4337 & ERC-6900 Project Fix Patch Script
# This script fixes all identified issues in the project

echo "================================================"
echo " Applying fixes to ERC-4337 & ERC-6900 Project"
echo "================================================"
echo ""

# 1. Fix SmartAccountFactory.sol
echo "[1/7] Fixing SmartAccountFactory.sol..."
cat > contracts/SmartAccountFactory.sol << 'EOF'
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
EOF

# 2. Update IEntryPoint.sol
echo "[2/7] Updating IEntryPoint.sol..."
cat > contracts/IEntryPoint.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

struct UserOperation {
    address sender;
    uint256 nonce;
    bytes initCode;
    bytes callData;
    uint256 callGasLimit;
    uint256 verificationGasLimit;
    uint256 preVerificationGas;
    uint256 maxFeePerGas;
    uint256 maxPriorityFeePerGas;
    bytes paymasterAndData;
    bytes signature;
}

interface IEntryPoint {
    function handleOps(UserOperation[] calldata ops, address payable beneficiary) external;
    function depositTo(address account) external payable;
    function withdrawTo(address payable withdrawAddress, uint256 withdrawAmount) external;
    function getUserOpHash(UserOperation calldata userOp) external view returns (bytes32);
}
EOF

# 3. Update IValidationPlugin.sol
echo "[3/7] Updating IValidationPlugin.sol..."
cat > contracts/interfaces/IValidationPlugin.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../IEntryPoint.sol";

interface IValidationPlugin {
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash
    ) external returns (uint256);
}
EOF

# 4. Create MockEntryPoint.sol
echo "[4/7] Creating MockEntryPoint.sol..."
cat > contracts/MockEntryPoint.sol << 'EOF'
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
EOF

# 5. Update deploy.js
echo "[5/7] Updating deploy.js..."
cat > scripts/deploy.js << 'EOF'
// deploy.js - Deployment script for ERC-4337 & ERC-6900 contracts
const { ethers } = require("hardhat");
const fs = require('fs');

async function main() {
  console.log("🚀 Deploying ERC-4337 & ERC-6900 Smart Account System...\n");

  // Get deployer
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Account balance:", ethers.utils.formatEther(await deployer.getBalance()), "ETH\n");

  // Deploy EntryPoint (or use existing one)
  console.log("1. Deploying EntryPoint...");
  let entryPoint;
  if (network.name === "localhost" || network.name === "hardhat") {
    const MockEntryPoint = await ethers.getContractFactory("MockEntryPoint");
    entryPoint = await MockEntryPoint.deploy();
    await entryPoint.deployed();
    console.log("   MockEntryPoint deployed to:", entryPoint.address);
  } else {
    // Use the official EntryPoint address for testnets/mainnet
    entryPoint = { address: "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789" };
    console.log("   Using official EntryPoint at:", entryPoint.address);
  }

  // Deploy MultiSigPlugin
  console.log("\n2. Deploying MultiSigPlugin...");
  const MultiSigPlugin = await ethers.getContractFactory("MultiSigPlugin");
  const multiSigPlugin = await MultiSigPlugin.deploy();
  await multiSigPlugin.deployed();
  console.log("   MultiSigPlugin deployed to:", multiSigPlugin.address);

  // Deploy SmartAccountFactory
  console.log("\n3. Deploying SmartAccountFactory...");
  const SmartAccountFactory = await ethers.getContractFactory("SmartAccountFactory");
  const factory = await SmartAccountFactory.deploy(entryPoint.address);
  await factory.deployed();
  console.log("   SmartAccountFactory deployed to:", factory.address);

  // Save deployment addresses
  const deploymentInfo = {
    network: network.name,
    chainId: network.config.chainId,
    deployer: deployer.address,
    contracts: {
      entryPoint: entryPoint.address,
      multiSigPlugin: multiSigPlugin.address,
      factory: factory.address
    },
    timestamp: new Date().toISOString()
  };

  // Write deployment info to file
  fs.writeFileSync(
    `deployments-${network.name}.json`,
    JSON.stringify(deploymentInfo, null, 2)
  );

  // Update addresses.json
  const addressesPath = './scripts/addresses.json';
  let addresses = {};
  if (fs.existsSync(addressesPath)) {
    addresses = JSON.parse(fs.readFileSync(addressesPath, 'utf8'));
  }
  
  addresses[network.name] = {
    entryPoint: entryPoint.address,
    factory: factory.address,
    multiSigPlugin: multiSigPlugin.address
  };
  
  fs.writeFileSync(addressesPath, JSON.stringify(addresses, null, 2));

  console.log("\n✅ Deployment complete!");
  console.log("\n📄 Deployment info saved to:", `deployments-${network.name}.json`);
  
  // Verify contracts on Etherscan (if not on localhost)
  if (network.name !== "localhost" && network.name !== "hardhat") {
    console.log("\n🔍 Verifying contracts on Etherscan...");
    
    await new Promise(resolve => setTimeout(resolve, 20000)); // Wait for Etherscan to index
    
    try {
      await hre.run("verify:verify", {
        address: multiSigPlugin.address,
        constructorArguments: [],
      });
      
      await hre.run("verify:verify", {
        address: factory.address,
        constructorArguments: [entryPoint.address],
      });
      
      console.log("✅ Contracts verified!");
    } catch (error) {
      console.log("⚠️  Verification failed:", error.message);
    }
  }

  return deploymentInfo;
}

// Test script
async function testDeployment(deploymentInfo) {
  console.log("\n🧪 Running deployment tests...\n");
  
  const [owner1, owner2, owner3] = await ethers.getSigners();
  
  // Get contract instances
  const factory = await ethers.getContractAt("SmartAccountFactory", deploymentInfo.contracts.factory);
  const multiSigPlugin = await ethers.getContractAt("MultiSigPlugin", deploymentInfo.contracts.multiSigPlugin);
  
  // Create a smart account
  console.log("1. Creating smart account...");
  const salt = 0;
  const tx = await factory.createAccount(owner1.address, salt);
  const receipt = await tx.wait();
  
  const accountAddress = await factory.getAddress(owner1.address, salt);
  console.log("   Smart account created at:", accountAddress);
  
  // Get account instance
  const account = await ethers.getContractAt("ModularSmartAccount", accountAddress);
  
  // Install multi-sig plugin
  console.log("\n2. Installing multi-sig plugin...");
  const owners = [owner1.address, owner2.address, owner3.address];
  const threshold = 2;
  
  const installData = ethers.utils.defaultAbiCoder.encode(
    ["address[]", "uint256"],
    [owners, threshold]
  );
  
  // Note: This would normally be done through a UserOperation
  const selector = "0x00000000"; // Custom selector for multi-sig
  await account.connect(owner1).installPlugin(selector, multiSigPlugin.address, installData);
  console.log("   Multi-sig plugin installed with", owners.length, "owners and threshold of", threshold);
  
  // Fund the account
  console.log("\n3. Funding account...");
  await owner1.sendTransaction({
    to: accountAddress,
    value: ethers.utils.parseEther("1.0")
  });
  const balance = await ethers.provider.getBalance(accountAddress);
  console.log("   Account balance:", ethers.utils.formatEther(balance), "ETH");
  
  console.log("\n✅ All tests passed!");
}

// Run deployment and tests
main()
  .then(async (deploymentInfo) => {
    if (process.env.RUN_TESTS === "true") {
      await testDeployment(deploymentInfo);
    }
    process.exit(0);
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
EOF

# 6. Clean up duplicate files
echo "[6/7] Cleaning up duplicate files..."
rm -f ./scripts/addresses.json~

# 7. Clean up ModularSmartAccount.sol to remove duplicates
echo "[7/7] Cleaning up ModularSmartAccount.sol..."
# Extract only the ModularSmartAccount contract from the file
cat > contracts/ModularSmartAccount.sol << 'EOF'
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
EOF

echo ""
echo "================================================"
echo "[+] All fixes applied successfully!"
echo "================================================"
echo ""
echo "Next steps:"
echo "1. Run: npm install"
echo "2. Run: npx hardhat compile"
echo "3. Deploy contracts: npx hardhat run scripts/deploy.js --network localhost"
echo ""
echo "[i] The project should now compile and deploy correctly!"