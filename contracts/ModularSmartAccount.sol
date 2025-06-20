// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// ERC-4337 Interfaces
interface IAccount {
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external returns (uint256 validationData);
}

interface IEntryPoint {
    function depositTo(address account) external payable;
    function withdrawTo(address payable withdrawAddress, uint256 withdrawAmount) external;
}

// ERC-6900 Interfaces
interface IPlugin {
    function onInstall(bytes calldata data) external;
    function onUninstall(bytes calldata data) external;
}

interface IValidationPlugin {
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash
    ) external returns (uint256);
}

// UserOperation struct for ERC-4337
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

// Multi-Signature Plugin for ERC-6900
contract MultiSigPlugin is IPlugin, IValidationPlugin {
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
    }
    
    mapping(address => mapping(address => bool)) public isOwner;
    mapping(address => address[]) public owners;
    mapping(address => uint256) public requiredConfirmations;
    mapping(address => mapping(uint256 => Transaction)) public transactions;
    mapping(address => mapping(uint256 => mapping(address => bool))) public confirmations;
    mapping(address => uint256) public transactionCount;
    
    event OwnerAdded(address indexed account, address indexed owner);
    event OwnerRemoved(address indexed account, address indexed owner);
    event TransactionSubmitted(address indexed account, uint256 indexed txId);
    event TransactionConfirmed(address indexed account, uint256 indexed txId, address indexed owner);
    event TransactionExecuted(address indexed account, uint256 indexed txId);
    
    function onInstall(bytes calldata data) external override {
        (address[] memory _owners, uint256 _required) = abi.decode(data, (address[], uint256));
        require(_owners.length >= _required, "Invalid threshold");
        require(_required > 0, "Threshold must be > 0");
        
        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), "Invalid owner");
            require(!isOwner[msg.sender][_owners[i]], "Duplicate owner");
            
            isOwner[msg.sender][_owners[i]] = true;
            owners[msg.sender].push(_owners[i]);
            emit OwnerAdded(msg.sender, _owners[i]);
        }
        
        requiredConfirmations[msg.sender] = _required;
    }
    
    function onUninstall(bytes calldata) external override {
        address[] memory _owners = owners[msg.sender];
        for (uint256 i = 0; i < _owners.length; i++) {
            isOwner[msg.sender][_owners[i]] = false;
        }
        delete owners[msg.sender];
        delete requiredConfirmations[msg.sender];
    }
    
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash
    ) external view override returns (uint256) {
        // Decode the signature to get the signers
        address[] memory signers = abi.decode(userOp.signature, (address[]));
        
        uint256 validSignatures = 0;
        for (uint256 i = 0; i < signers.length; i++) {
            if (isOwner[userOp.sender][signers[i]]) {
                validSignatures++;
            }
        }
        
        if (validSignatures >= requiredConfirmations[userOp.sender]) {
            return 0; // Validation success
        }
        return 1; // Validation failed
    }
    
    function submitTransaction(
        address _to,
        uint256 _value,
        bytes calldata _data
    ) external returns (uint256) {
        require(isOwner[msg.sender][tx.origin], "Not an owner");
        
        uint256 txId = transactionCount[msg.sender];
        transactions[msg.sender][txId] = Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            confirmations: 1
        });
        
        confirmations[msg.sender][txId][tx.origin] = true;
        transactionCount[msg.sender]++;
        
        emit TransactionSubmitted(msg.sender, txId);
        emit TransactionConfirmed(msg.sender, txId, tx.origin);
        
        return txId;
    }
    
    function confirmTransaction(uint256 _txId) external {
        require(isOwner[msg.sender][tx.origin], "Not an owner");
        require(!confirmations[msg.sender][_txId][tx.origin], "Already confirmed");
        require(!transactions[msg.sender][_txId].executed, "Already executed");
        
        confirmations[msg.sender][_txId][tx.origin] = true;
        transactions[msg.sender][_txId].confirmations++;
        
        emit TransactionConfirmed(msg.sender, _txId, tx.origin);
        
        if (transactions[msg.sender][_txId].confirmations >= requiredConfirmations[msg.sender]) {
            executeTransaction(_txId);
        }
    }
    
    function executeTransaction(uint256 _txId) internal {
        Transaction storage txn = transactions[msg.sender][_txId];
        require(!txn.executed, "Already executed");
        require(txn.confirmations >= requiredConfirmations[msg.sender], "Not enough confirmations");
        
        txn.executed = true;
        
        (bool success,) = txn.to.call{value: txn.value}(txn.data);
        require(success, "Transaction failed");
        
        emit TransactionExecuted(msg.sender, _txId);
    }
}

// Modular Smart Account (ERC-4337 + ERC-6900)
contract ModularSmartAccount is IAccount {
    IEntryPoint public immutable entryPoint;
    uint256 public nonce;
    
    mapping(bytes4 => address) public plugins;
    
    event PluginInstalled(bytes4 indexed selector, address indexed plugin);
    event PluginUninstalled(bytes4 indexed selector);
    
    modifier onlyEntryPoint() {
        require(msg.sender == address(entryPoint), "Only EntryPoint");
        _;
    }
    
    constructor(IEntryPoint _entryPoint) {
        entryPoint = _entryPoint;
    }
    
    receive() external payable {}
    
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external override onlyEntryPoint returns (uint256 validationData) {
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
        
        if (signer == address(this)) {
            return 0; // Valid
        }
        return 1; // Invalid
    }
    
    function recoverSigner(bytes32 hash, bytes memory signature) internal pure returns (address) {
        require(signature.length == 65, "Invalid signature length");
        
        bytes32 r;
        bytes32 s;
        uint8 v;
        
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }
        
        return ecrecover(hash, v, r, s);
    }
    
    function installPlugin(bytes4 selector, address plugin, bytes calldata data) external {
        require(msg.sender == address(this), "Only self");
        require(plugins[selector] == address(0), "Plugin already installed");
        
        plugins[selector] = plugin;
        IPlugin(plugin).onInstall(data);
        
        emit PluginInstalled(selector, plugin);
    }
    
    function uninstallPlugin(bytes4 selector, bytes calldata data) external {
        require(msg.sender == address(this), "Only self");
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

// Factory for creating smart accounts
contract SmartAccountFactory {
    IEntryPoint public immutable entryPoint;
    address public immutable accountImplementation;
    
    event AccountCreated(address indexed account, address indexed owner);
    
    constructor(IEntryPoint _entryPoint) {
        entryPoint = _entryPoint;
        accountImplementation = address(new ModularSmartAccount(_entryPoint));
    }
    
    function createAccount(address owner, uint256 salt) external returns (address) {
        bytes32 bytecodeHash = keccak256(
            abi.encodePacked(
                type(ModularSmartAccount).creationCode,
                abi.encode(entryPoint)
            )
        );
        
        address account = address(uint160(uint256(keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                bytecodeHash
            )
        ))));
        
        if (account.code.length == 0) {
            account = address(new ModularSmartAccount{salt: bytes32(salt)}(entryPoint));
            emit AccountCreated(account, owner);
        }
        
        return account;
    }
    
    function getAddress(address owner, uint256 salt) external view returns (address) {
        bytes32 bytecodeHash = keccak256(
            abi.encodePacked(
                type(ModularSmartAccount).creationCode,
                abi.encode(entryPoint)
            )
        );
        
        return address(uint160(uint256(keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                bytecodeHash
            )
        ))));
    }
}