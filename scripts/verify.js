// Contract verification script
const hre = require("hardhat");

async function main() {
  console.log("[>] Verifying contracts on Etherscan...");
  
  // Load deployment addresses
  const addresses = require("./addresses.json")[hre.network.name];
  
  if (addresses.multiSigPlugin) {
    await hre.run("verify:verify", {
      address: addresses.multiSigPlugin,
      constructorArguments: [],
    });
  }
  
  if (addresses.factory) {
    await hre.run("verify:verify", {
      address: addresses.factory,
      constructorArguments: [addresses.entryPoint],
    });
  }
  
  console.log("[+] Verification complete!");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
