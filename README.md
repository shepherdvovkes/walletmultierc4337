# ERC-4337 & ERC-6900 Smart Account MVP

```
 _____ ____   ____      _  _  _____ _____ _____ 
| ____|  _ \ / ___|    | || ||___ /|___ /|___  |
|  _| | |_) | |   _____| || |_ |_ \  |_ \   / / 
| |___|  _ <| |__|_____|__   _|__) |___) | / /  
|_____|_| \_\\____|       |_| |____/|____/ /_/   
                                                 
 __  __       _ _   _       ____  _       
|  \/  |_   _| | |_(_)     / ___|(_) __ _ 
| |\/| | | | | | __| |____| |  _ | |/ _` |
| |  | | |_| | | |_| |____| |_| || | (_| |
|_|  |_|\__,_|_|\__|_|     \____||_|\__, |
                                    |___/ 
```

A complete implementation of ERC-4337 Account Abstraction with ERC-6900 modular plugins, featuring multi-signature functionality.

## [+] Features

- **ERC-4337 Account Abstraction**: Full implementation of smart contract wallets
- **ERC-6900 Modular System**: Plugin-based architecture for extensibility
- **Multi-Signature Support**: Configurable threshold signatures
- **React GUI**: Interactive interface for testing
- **Complete Wallet SDK**: JavaScript library for integration

## [*] Prerequisites

- Node.js v16+
- npm or yarn
- MetaMask or any Web3 wallet
- Hardhat for contract deployment

## [!] Installation

1. **Clone the repository**
```bash
git clone <your-repo>
cd erc4337-multisig-mvp
```

2. **Install dependencies**
```bash
npm install
```

3. **Install Hardhat and dependencies**
```bash
npm install --save-dev hardhat @nomiclabs/hardhat-ethers @nomiclabs/hardhat-waffle ethereum-waffle chai ethers
```

4. **Create `.env` file**
```bash
# For testnet deployment
SEPOLIA_RPC_URL=your_rpc_url
MUMBAI_RPC_URL=your_rpc_url
PRIVATE_KEY=your_private_key
ETHERSCAN_API_KEY=your_api_key
```

## [#] Project Structure

```
├── contracts/
│   ├── ModularSmartAccount.sol    # Main smart account implementation
│   ├── MultiSigPlugin.sol         # Multi-signature plugin
│   └── SmartAccountFactory.sol    # Factory for deploying accounts
├── src/
│   ├── wallet.js                  # JavaScript wallet SDK
│   └── SmartAccountDashboard.jsx  # React GUI component
├── scripts/
│   └── deploy.js                  # Deployment script
└── README.md
```

## [>] Quick Start

### 1. Deploy Contracts

**Local deployment:**
```bash
npx hardhat node  # In one terminal
npx hardhat run scripts/deploy.js --network localhost  # In another terminal
```

**Testnet deployment:**
```bash
npx hardhat run scripts/deploy.js --network sepolia
```

### 2. Run the GUI

Create a simple React app:
```bash
npx create-react-app smart-account-gui
cd smart-account-gui
npm install ethers lucide-react
```

Copy the `SmartAccountDashboard.jsx` to `src/App.js` and run:
```bash
npm start
```

### 3. Using the Wallet SDK

```javascript
import { SmartAccountWallet } from './wallet.js';

// Initialize wallet
const wallet = new SmartAccountWallet(
  provider,
  entryPointAddress,
  factoryAddress,
  multiSigPluginAddress
);

// Create account
await wallet.init(privateKey);
const accountAddress = await wallet.createAccount();

// Install multi-sig plugin
await wallet.installMultiSigPlugin(
  [owner1, owner2, owner3],  // owners
  2                          // threshold
);

// Submit transaction
await wallet.submitMultiSigTransaction(
  recipientAddress,
  ethers.utils.parseEther("0.1"),
  "0x"  // data
);
```

## [@] Contract Interfaces

### ModularSmartAccount
- `validateUserOp()`: Validates UserOperations (ERC-4337)
- `installPlugin()`: Installs a new plugin (ERC-6900)
- `execute()`: Executes transactions
- `executeBatch()`: Executes multiple transactions

### MultiSigPlugin
- `onInstall()`: Configures owners and threshold
- `submitTransaction()`: Creates new multi-sig transaction
- `confirmTransaction()`: Adds confirmation
- `executeTransaction()`: Executes when threshold is met

## [?] Testing

Run the test suite:
```bash
RUN_TESTS=true npx hardhat run scripts/deploy.js --network localhost
```

## [~] Configuration

### EntryPoint Address
- Mainnet/Testnet: `0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789`
- Local: Deploy your own or use the one from deployment

### Gas Configuration
Adjust in `wallet.js`:
```javascript
callGasLimit: 200000,
verificationGasLimit: 100000,
preVerificationGas: 50000,
```

## [=] Network Support

- Ethereum Mainnet
- Sepolia Testnet
- Polygon Mumbai
- Local Hardhat Network

## [!] Security Considerations

This is an MVP implementation. For production:
- Audit all smart contracts
- Implement proper signature validation
- Add access control mechanisms
- Use a production-ready bundler
- Implement proper nonce management

## [i] Resources

- [ERC-4337 Specification](https://eips.ethereum.org/EIPS/eip-4337)
- [ERC-6900 Specification](https://eips.ethereum.org/EIPS/eip-6900)
- [Account Abstraction Documentation](https://docs.stackup.sh/)

## [&] Contributing

Feel free to submit issues and enhancement requests!

## [c] License

MIT License