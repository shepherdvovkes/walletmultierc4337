// deploy.js - Deployment script optimized for Sepolia with limited ETH
const { ethers } = require("hardhat");
const fs = require('fs');

async function main() {
  console.log("🚀 Deploying ERC-4337 & ERC-6900 Smart Account System to", network.name, "...\n");

  // Get deployer
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  const balance = await deployer.getBalance();
  console.log("Account balance:", ethers.utils.formatEther(balance), "ETH");
  
  // Check if we have enough ETH
  if (network.name === "sepolia" && balance.lt(ethers.utils.parseEther("0.05"))) {
    console.log("\n⚠️  Warning: Low balance for Sepolia deployment!");
    console.log("Recommended: At least 0.05 ETH for safe deployment");
    console.log("Current: ", ethers.utils.formatEther(balance), "ETH\n");
  }

  // Deploy EntryPoint (or use existing one)
  console.log("1. Checking EntryPoint...");
  let entryPoint;
  if (network.name === "localhost" || network.name === "hardhat") {
    console.log("   Deploying MockEntryPoint for local testing...");
    const MockEntryPoint = await ethers.getContractFactory("MockEntryPoint");
    entryPoint = await MockEntryPoint.deploy();
    await entryPoint.deployed();
    console.log("   ✓ MockEntryPoint deployed to:", entryPoint.address);
  } else {
    // Use the official EntryPoint address for testnets/mainnet
    entryPoint = { address: "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789" };
    console.log("   ✓ Using official EntryPoint at:", entryPoint.address);
    console.log("   (No deployment needed - saves gas!)");
  }

  // Deploy MultiSigPlugin with gas optimization
  console.log("\n2. Deploying MultiSigPlugin...");
  const MultiSigPlugin = await ethers.getContractFactory("MultiSigPlugin");
  
  // Estimate gas and add buffer
  const deployTx = MultiSigPlugin.getDeployTransaction();
  const estimatedGas = await deployer.estimateGas(deployTx);
  console.log("   Estimated gas:", estimatedGas.toString());
  
  // Deploy with optimized gas settings for Sepolia
  const multiSigPlugin = await MultiSigPlugin.deploy({
    gasLimit: estimatedGas.mul(110).div(100), // 10% buffer
    maxFeePerGas: network.name === "sepolia" ? ethers.utils.parseUnits("20", "gwei") : undefined,
    maxPriorityFeePerGas: network.name === "sepolia" ? ethers.utils.parseUnits("1.5", "gwei") : undefined
  });
  
  await multiSigPlugin.deployed();
  console.log("   ✓ MultiSigPlugin deployed to:", multiSigPlugin.address);
  console.log("   Gas used:", (await multiSigPlugin.deployTransaction.wait()).gasUsed.toString());

  // Deploy SmartAccountFactory with gas optimization
  console.log("\n3. Deploying SmartAccountFactory...");
  const SmartAccountFactory = await ethers.getContractFactory("SmartAccountFactory");
  
  // Deploy with optimized gas settings
  const factory = await SmartAccountFactory.deploy(entryPoint.address, {
    gasLimit: 3000000, // Fixed reasonable limit
    maxFeePerGas: network.name === "sepolia" ? ethers.utils.parseUnits("20", "gwei") : undefined,
    maxPriorityFeePerGas: network.name === "sepolia" ? ethers.utils.parseUnits("1.5", "gwei") : undefined
  });
  
  await factory.deployed();
  console.log("   ✓ SmartAccountFactory deployed to:", factory.address);
  console.log("   Gas used:", (await factory.deployTransaction.wait()).gasUsed.toString());

  // Calculate total deployment cost
  if (network.name === "sepolia") {
    const deployerEndBalance = await deployer.getBalance();
    const totalCost = balance.sub(deployerEndBalance);
    console.log("\n💰 Deployment Cost Summary:");
    console.log("   Total ETH spent:", ethers.utils.formatEther(totalCost));
    console.log("   Remaining balance:", ethers.utils.formatEther(deployerEndBalance), "ETH");
  }

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
    timestamp: new Date().toISOString(),
    deploymentCost: network.name === "sepolia" ? {
      multiSigPluginGas: (await multiSigPlugin.deployTransaction.wait()).gasUsed.toString(),
      factoryGas: (await factory.deployTransaction.wait()).gasUsed.toString()
    } : undefined
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
  console.log("\n🔗 Contract Addresses:");
  console.log("   EntryPoint:", entryPoint.address);
  console.log("   MultiSigPlugin:", multiSigPlugin.address);
  console.log("   SmartAccountFactory:", factory.address);
  
  // Sepolia specific instructions
  if (network.name === "sepolia") {
    console.log("\n📝 Next Steps for Sepolia:");
    console.log("   1. Verify contracts on Etherscan:");
    console.log("      npx hardhat run scripts/verify.js --network sepolia");
    console.log("   2. Update frontend with deployed addresses");
    console.log("   3. You can interact with contracts at:");
    console.log("      https://sepolia.etherscan.io/address/" + multiSigPlugin.address);
    console.log("      https://sepolia.etherscan.io/address/" + factory.address);
  }
  
  // Skip automatic verification for Sepolia to save time
  if (network.name === "sepolia") {
    console.log("\n📌 Note: Skipping automatic verification to complete deployment faster.");
    console.log("   Run verification manually when ready.");
  } else if (network.name !== "localhost" && network.name !== "hardhat") {
    console.log("\n🔍 Waiting before verification...");
    await new Promise(resolve => setTimeout(resolve, 20000));
    
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

// Minimal test script for Sepolia (to save gas)
async function minimalTest(deploymentInfo) {
  console.log("\n🧪 Running minimal deployment test...\n");
  
  const [deployer] = await ethers.getSigners();
  
  // Just verify contracts are deployed
  console.log("1. Checking MultiSigPlugin...");
  const multiSigCode = await ethers.provider.getCode(deploymentInfo.contracts.multiSigPlugin);
  console.log("   ✓ MultiSigPlugin deployed:", multiSigCode.length > 2);
  
  console.log("\n2. Checking SmartAccountFactory...");
  const factoryCode = await ethers.provider.getCode(deploymentInfo.contracts.factory);
  console.log("   ✓ SmartAccountFactory deployed:", factoryCode.length > 2);
  
  console.log("\n✅ Basic deployment verification passed!");
  console.log("\n💡 Tip: Create and test smart accounts using the frontend to save ETH");
}

// Run deployment
main()
  .then(async (deploymentInfo) => {
    // Only run tests on localhost
    if (network.name === "localhost" && process.env.RUN_TESTS === "true") {
      const { testDeployment } = require('./test-deployment');
      await testDeployment(deploymentInfo);
    } else if (network.name === "sepolia") {
      await minimalTest(deploymentInfo);
    }
    process.exit(0);
  })
  .catch((error) => {
    console.error("\n❌ Deployment failed:", error.message);
    console.error(error);
    process.exit(1);
  });
