#!/bin/bash

echo "======================================"
echo " Deploying to Sepolia Testnet"
echo "======================================"
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found!"
    echo "Please copy .env.example to .env and add your keys"
    exit 1
fi

# Load environment variables
source .env

# Check if PRIVATE_KEY is set
if [ -z "$PRIVATE_KEY" ]; then
    echo "❌ Error: PRIVATE_KEY not set in .env!"
    exit 1
fi

# Check if SEPOLIA_RPC_URL is set
if [ -z "$SEPOLIA_RPC_URL" ]; then
    echo "❌ Error: SEPOLIA_RPC_URL not set in .env!"
    exit 1
fi

echo "✓ Environment configured"
echo ""

# Compile contracts
echo "📦 Compiling contracts..."
npx hardhat compile

if [ $? -ne 0 ]; then
    echo "❌ Compilation failed!"
    exit 1
fi

echo "✓ Contracts compiled"
echo ""

# Deploy to Sepolia
echo "🚀 Deploying to Sepolia..."
echo "This will use approximately 0.02-0.05 ETH"
echo ""

npx hardhat run scripts/deploy.js --network sepolia

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Deployment successful!"
    echo ""
    echo "📋 Check deployments-sepolia.json for contract addresses"
    echo ""
    echo "Next steps:"
    echo "1. Verify contracts: npx hardhat run scripts/verify.js --network sepolia"
    echo "2. Update frontend with the deployed addresses"
    echo "3. Test using the React GUI"
else
    echo ""
    echo "❌ Deployment failed!"
    echo "Check your ETH balance and try again"
fi
