// wallet.js - ERC-4337 Smart Account Wallet Implementation
import { ethers } from 'ethers';

class SmartAccountWallet {
    constructor(provider, entryPointAddress, factoryAddress, multiSigPluginAddress) {
        this.provider = provider;
        this.entryPointAddress = entryPointAddress;
        this.factoryAddress = factoryAddress;
        this.multiSigPluginAddress = multiSigPluginAddress;
        this.signer = null;
        this.accountAddress = null;
    }

    // Initialize wallet with a signer
    async init(privateKey) {
        this.signer = new ethers.Wallet(privateKey, this.provider);
        return this.signer.address;
    }

    // Create a new smart account
    async createAccount(salt = 0) {
        const factory = new ethers.Contract(
            this.factoryAddress,
            [
                'function createAccount(address owner, uint256 salt) returns (address)',
                'function getAddress(address owner, uint256 salt) view returns (address)'
            ],
            this.signer
        );

        // Get predicted address
        this.accountAddress = await factory.getAddress(this.signer.address, salt);
        
        // Check if already deployed
        const code = await this.provider.getCode(this.accountAddress);
        if (code === '0x') {
            // Deploy the account
            const tx = await factory.createAccount(this.signer.address, salt);
            await tx.wait();
        }

        return this.accountAddress;
    }

    // Install multi-sig plugin
    async installMultiSigPlugin(owners, threshold) {
        const account = new ethers.Contract(
            this.accountAddress,
            [
                'function installPlugin(bytes4 selector, address plugin, bytes data)'
            ],
            this.signer
        );

        // Selector for multi-sig validation
        const selector = '0x00000000'; // Custom selector for multi-sig operations
        
        // Encode installation data
        const installData = ethers.utils.defaultAbiCoder.encode(
            ['address[]', 'uint256'],
            [owners, threshold]
        );

        const userOp = await this.createUserOperation(
            account.interface.encodeFunctionData('installPlugin', [
                selector,
                this.multiSigPluginAddress,
                installData
            ])
        );

        return await this.sendUserOperation(userOp);
    }

    // Create a UserOperation
    async createUserOperation(callData, options = {}) {
        const account = new ethers.Contract(
            this.accountAddress,
            ['function nonce() view returns (uint256)'],
            this.provider
        );

        const nonce = await account.nonce();
        
        const userOp = {
            sender: this.accountAddress,
            nonce: nonce,
            initCode: '0x',
            callData: callData,
            callGasLimit: options.callGasLimit || 200000,
            verificationGasLimit: options.verificationGasLimit || 100000,
            preVerificationGas: options.preVerificationGas || 50000,
            maxFeePerGas: options.maxFeePerGas || ethers.utils.parseUnits('30', 'gwei'),
            maxPriorityFeePerGas: options.maxPriorityFeePerGas || ethers.utils.parseUnits('2', 'gwei'),
            paymasterAndData: '0x',
            signature: '0x'
        };

        // Sign the operation
        userOp.signature = await this.signUserOperation(userOp);

        return userOp;
    }

    // Sign a UserOperation
    async signUserOperation(userOp) {
        const userOpHash = this.getUserOpHash(userOp);
        const signature = await this.signer.signMessage(ethers.utils.arrayify(userOpHash));
        return signature;
    }

    // Calculate UserOperation hash
    getUserOpHash(userOp) {
        const packed = ethers.utils.defaultAbiCoder.encode(
            [
                'address',
                'uint256',
                'bytes32',
                'bytes32',
                'uint256',
                'uint256',
                'uint256',
                'uint256',
                'uint256',
                'bytes32'
            ],
            [
                userOp.sender,
                userOp.nonce,
                ethers.utils.keccak256(userOp.initCode),
                ethers.utils.keccak256(userOp.callData),
                userOp.callGasLimit,
                userOp.verificationGasLimit,
                userOp.preVerificationGas,
                userOp.maxFeePerGas,
                userOp.maxPriorityFeePerGas,
                ethers.utils.keccak256(userOp.paymasterAndData)
            ]
        );

        const encoded = ethers.utils.defaultAbiCoder.encode(
            ['bytes32', 'address', 'uint256'],
            [ethers.utils.keccak256(packed), this.entryPointAddress, this.provider.network.chainId]
        );

        return ethers.utils.keccak256(encoded);
    }

    // Send UserOperation to the EntryPoint
    async sendUserOperation(userOp) {
        const entryPoint = new ethers.Contract(
            this.entryPointAddress,
            [
                'function handleOps(tuple(address sender, uint256 nonce, bytes initCode, bytes callData, uint256 callGasLimit, uint256 verificationGasLimit, uint256 preVerificationGas, uint256 maxFeePerGas, uint256 maxPriorityFeePerGas, bytes paymasterAndData, bytes signature)[] ops, address beneficiary)'
            ],
            this.signer
        );

        const tx = await entryPoint.handleOps([userOp], this.signer.address);
        return await tx.wait();
    }

    // Execute a transaction through the smart account
    async execute(to, value, data) {
        const account = new ethers.Contract(
            this.accountAddress,
            ['function execute(address to, uint256 value, bytes data)'],
            this.provider
        );

        const callData = account.interface.encodeFunctionData('execute', [to, value, data]);
        const userOp = await this.createUserOperation(callData);

        return await this.sendUserOperation(userOp);
    }

    // Execute batch transactions
    async executeBatch(targets, values, datas) {
        const account = new ethers.Contract(
            this.accountAddress,
            ['function executeBatch(address[] to, uint256[] value, bytes[] data)'],
            this.provider
        );

        const callData = account.interface.encodeFunctionData('executeBatch', [targets, values, datas]);
        const userOp = await this.createUserOperation(callData);

        return await this.sendUserOperation(userOp);
    }

    // Submit a multi-sig transaction
    async submitMultiSigTransaction(to, value, data) {
        const multiSig = new ethers.Contract(
            this.multiSigPluginAddress,
            [
                'function submitTransaction(address to, uint256 value, bytes data) returns (uint256)'
            ],
            this.signer
        );

        const callData = multiSig.interface.encodeFunctionData('submitTransaction', [to, value, data]);
        
        // Execute through the smart account
        return await this.execute(this.multiSigPluginAddress, 0, callData);
    }

    // Confirm a multi-sig transaction
    async confirmMultiSigTransaction(txId) {
        const multiSig = new ethers.Contract(
            this.multiSigPluginAddress,
            ['function confirmTransaction(uint256 txId)'],
            this.signer
        );

        const callData = multiSig.interface.encodeFunctionData('confirmTransaction', [txId]);
        
        // Execute through the smart account
        return await this.execute(this.multiSigPluginAddress, 0, callData);
    }

    // Get account balance
    async getBalance() {
        return await this.provider.getBalance(this.accountAddress);
    }

    // Deposit to EntryPoint
    async depositToEntryPoint(amount) {
        const entryPoint = new ethers.Contract(
            this.entryPointAddress,
            ['function depositTo(address account) payable'],
            this.signer
        );

        const tx = await entryPoint.depositTo(this.accountAddress, { value: amount });
        return await tx.wait();
    }
}

// Bundler client for submitting UserOperations
class BundlerClient {
    constructor(bundlerUrl) {
        this.bundlerUrl = bundlerUrl;
    }

    async sendUserOperation(userOp, entryPoint) {
        const response = await fetch(`${this.bundlerUrl}/rpc`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                jsonrpc: '2.0',
                method: 'eth_sendUserOperation',
                params: [userOp, entryPoint],
                id: 1
            })
        });

        const result = await response.json();
        if (result.error) {
            throw new Error(result.error.message);
        }

        return result.result;
    }

    async getUserOperationReceipt(userOpHash) {
        const response = await fetch(`${this.bundlerUrl}/rpc`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                jsonrpc: '2.0',
                method: 'eth_getUserOperationReceipt',
                params: [userOpHash],
                id: 1
            })
        });

        const result = await response.json();
        return result.result;
    }
}

export { SmartAccountWallet, BundlerClient };