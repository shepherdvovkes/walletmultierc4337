#!/bin/bash

# ERC-4337 & ERC-6900 Smart Account MVP Setup Script
# This script creates the complete project structure with placeholder files

echo "============================================="
echo " ERC-4337 & ERC-6900 Smart Account MVP Setup"
echo "============================================="
echo ""

# Check if we're in a project directory
if [ ! -f "package.json" ] && [ -z "$(ls -A)" ]; then
    echo "[>] Initializing project in current directory: $(pwd)"
else
    echo "[!] Warning: Current directory is not empty."
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "[x] Setup cancelled."
        exit 1
    fi
fi

# Create directory structure
echo "[>] Creating directory structure..."
mkdir -p contracts
mkdir -p frontend/public
mkdir -p frontend/src/components
mkdir -p frontend/src/utils
mkdir -p scripts
mkdir -p test

# Create root files
echo "[>] Creating root configuration files..."

# Create package.json
cat > package.json << 'EOF'
{
  "name": "erc4337-multisig-mvp",
  "version": "1.0.0",
  "description": "ERC-4337 & ERC-6900 Smart Account MVP with Multi-Sig",
  "scripts": {
    "compile": "hardhat compile",
    "deploy": "hardhat run scripts/deploy.js",
    "deploy:local": "hardhat run scripts/deploy.js --network localhost",
    "deploy:sepolia": "hardhat run scripts/deploy.js --network sepolia",
    "test": "hardhat test",
    "node": "hardhat node"
  },
  "keywords": ["erc4337", "erc6900", "smart-account", "multisig"],
  "author": "",
  "license": "MIT",
  "devDependencies": {
    "@nomiclabs/hardhat-ethers": "^2.0.0",
    "@nomiclabs/hardhat-etherscan": "^3.0.0",
    "@nomiclabs/hardhat-waffle": "^2.0.0",
    "chai": "^4.2.0",
    "ethereum-waffle": "^3.0.0",
    "ethers": "^5.0.0",
    "hardhat": "^2.12.0"
  }
}
EOF

# Create hardhat.config.js
cat > hardhat.config.js << 'EOF'
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("dotenv").config();

module.exports = {
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    hardhat: {
      chainId: 31337
    },
    localhost: {
      url: "http://127.0.0.1:8545"
    },
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL || "",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : []
    },
    goerli: {
      url: process.env.GOERLI_RPC_URL || "",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : []
    }
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY
  }
};
EOF

# Create .env.example
cat > .env.example << 'EOF'
# RPC URLs
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_INFURA_KEY
GOERLI_RPC_URL=https://goerli.infura.io/v3/YOUR_INFURA_KEY

# Private key (without 0x prefix)
PRIVATE_KEY=your_private_key_here

# Etherscan API key for verification
ETHERSCAN_API_KEY=your_etherscan_api_key
EOF

# Create .gitignore
cat > .gitignore << 'EOF'
# Dependencies
node_modules/
frontend/node_modules/

# Environment files
.env
.env.local

# Hardhat files
cache/
artifacts/
typechain/
typechain-types/

# Coverage
coverage/
coverage.json

# Builds
build/
dist/
frontend/build/

# IDE
.vscode/
.idea/

# OS
.DS_Store
*.log

# Deployment files
deployments-*.json
EOF

# Create contract placeholders
echo "[>] Creating contract placeholders..."

# EntryPoint interface placeholder
cat > contracts/IEntryPoint.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Placeholder for IEntryPoint interface
// Full implementation will be added manually
interface IEntryPoint {
    // ERC-4337 EntryPoint interface
}
EOF

# Create test file
cat > test/MultiSig.test.js << 'EOF'
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MultiSig Smart Account", function () {
  let factory, multiSigPlugin, account;
  let owner1, owner2, owner3;

  beforeEach(async function () {
    [owner1, owner2, owner3] = await ethers.getSigners();
    
    // Deploy contracts
    // TODO: Add deployment logic
  });

  describe("Account Creation", function () {
    it("Should create a new smart account", async function () {
      // TODO: Add test
    });
  });

  describe("Multi-Sig Operations", function () {
    it("Should submit and confirm transactions", async function () {
      // TODO: Add test
    });
  });
});
EOF

# Create frontend files
echo "[>] Creating frontend structure..."

# Frontend package.json
cat > frontend/package.json << 'EOF'
{
  "name": "erc4337-multisig-frontend",
  "version": "0.1.0",
  "private": true,
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-scripts": "5.0.1",
    "lucide-react": "^0.263.1"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "eslintConfig": {
    "extends": ["react-app"]
  },
  "browserslist": {
    "production": [">0.2%", "not dead", "not op_mini all"],
    "development": ["last 1 chrome version", "last 1 firefox version", "last 1 safari version"]
  }
}
EOF

# Frontend index.html
cat > frontend/public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta name="description" content="ERC-4337 & ERC-6900 Multi-Sig Wallet" />
  <title>Smart Account Multi-Sig</title>
  <script src="https://cdn.tailwindcss.com"></script>
</head>
<body>
  <noscript>You need to enable JavaScript to run this app.</noscript>
  <div id="root"></div>
</body>
</html>
EOF

# Frontend index.js
cat > frontend/src/index.js << 'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF

# Frontend App.js
cat > frontend/src/App.js << 'EOF'
import React from 'react';
import SmartAccountDashboard from './components/SmartAccountDashboard';

function App() {
  return (
    <div className="App">
      <SmartAccountDashboard />
    </div>
  );
}

export default App;
EOF

# Create placeholder for components
cat > frontend/src/components/.gitkeep << 'EOF'
# Place SmartAccountDashboard.jsx here
EOF

cat > frontend/src/utils/.gitkeep << 'EOF'
# Place wallet.js here
EOF

# Create deployment addresses tracker
cat > scripts/addresses.json << 'EOF'
{
  "localhost": {
    "entryPoint": "",
    "factory": "",
    "multiSigPlugin": ""
  },
  "sepolia": {
    "entryPoint": "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789",
    "factory": "",
    "multiSigPlugin": ""
  },
  "goerli": {
    "entryPoint": "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789",
    "factory": "",
    "multiSigPlugin": ""
  }
}
EOF

# Create deployment helper script
cat > scripts/verify.js << 'EOF'
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
EOF

# Create main README placeholder
cat > README.md << 'EOF'
# ERC-4337 & ERC-6900 Smart Account MVP

[!] Full README will be added manually

## Quick Setup

1. Install dependencies:
   ```bash
   npm install
   cd frontend && npm install
   ```

2. Copy environment file:
   ```bash
   cp .env.example .env
   # Edit .env with your values
   ```

3. Deploy contracts:
   ```bash
   npm run deploy:local
   ```

4. Start frontend:
   ```bash
   cd frontend && npm start
   ```
EOF

# Create contract placeholders note
cat > contracts/README.md << 'EOF'
# Smart Contracts

Place the following files here:
- ModularSmartAccount.sol
- MultiSigPlugin.sol  
- SmartAccountFactory.sol

These files contain the main implementation and should be added manually.
EOF

# Make scripts executable
chmod +x scripts/*.js

# Final message
echo ""
echo "============================================="
echo "[+] Project structure created successfully!"
echo "============================================="
echo ""
echo "Next steps:"
echo "1. Copy the generated contract files to contracts/"
echo "2. Copy SmartAccountDashboard.jsx to frontend/src/components/"
echo "3. Copy wallet.js to frontend/src/utils/"
echo "4. Copy deploy.js to scripts/"
echo "5. Copy the full README.md to the root"
echo ""
echo "Then run:"
echo "  npm install"
echo "  cd frontend && npm install"
echo ""
echo "[i] Don't forget to:"
echo "  - Copy .env.example to .env and add your keys"
echo "  - Update contract addresses in scripts/addresses.json after deployment"
echo ""