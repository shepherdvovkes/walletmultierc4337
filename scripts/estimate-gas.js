// estimate-gas.js - Estimate deployment costs
const { ethers } = require("hardhat");

async function main() {
  console.log("💰 Estimating deployment costs for", network.name, "...\n");
  
  const [deployer] = await ethers.getSigners();
  
  // Get current gas prices
  const gasPrice = await deployer.getGasPrice();
  console.log("Current gas price:", ethers.utils.formatUnits(gasPrice, "gwei"), "gwei");
  
  // Estimate MockEntryPoint (only for localhost)
  if (network.name === "localhost") {
    const MockEntryPoint = await ethers.getContractFactory("MockEntryPoint");
    const mockGas = await deployer.estimateGas(MockEntryPoint.getDeployTransaction());
    console.log("\nMockEntryPoint:");
    console.log("  Gas:", mockGas.toString());
    console.log("  Cost:", ethers.utils.formatEther(mockGas.mul(gasPrice)), "ETH");
  }
  
  // Estimate MultiSigPlugin
  const MultiSigPlugin = await ethers.getContractFactory("MultiSigPlugin");
  const multiSigGas = await deployer.estimateGas(MultiSigPlugin.getDeployTransaction());
  console.log("\nMultiSigPlugin:");
  console.log("  Gas:", multiSigGas.toString());
  console.log("  Cost:", ethers.utils.formatEther(multiSigGas.mul(gasPrice)), "ETH");
  
  // Estimate SmartAccountFactory
  const SmartAccountFactory = await ethers.getContractFactory("SmartAccountFactory");
  const factoryGas = await deployer.estimateGas(
    SmartAccountFactory.getDeployTransaction("0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789")
  );
  console.log("\nSmartAccountFactory:");
  console.log("  Gas:", factoryGas.toString());
  console.log("  Cost:", ethers.utils.formatEther(factoryGas.mul(gasPrice)), "ETH");
  
  // Total
  const totalGas = multiSigGas.add(factoryGas);
  const totalCost = totalGas.mul(gasPrice);
  console.log("\n📊 Total Deployment Cost:");
  console.log("  Total Gas:", totalGas.toString());
  console.log("  Total Cost:", ethers.utils.formatEther(totalCost), "ETH");
  
  // With 50% buffer
  const bufferedCost = totalCost.mul(150).div(100);
  console.log("  With 50% buffer:", ethers.utils.formatEther(bufferedCost), "ETH");
  
  if (network.name === "sepolia") {
    console.log("\n💡 Sepolia Deployment Tips:");
    console.log("  - Current balance needed: ~", ethers.utils.formatEther(bufferedCost), "ETH");
    console.log("  - Your 0.1 ETH should be sufficient!");
    console.log("  - Use the deploy-sepolia.sh script for easy deployment");
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
