// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IPlugin.sol";
import "./interfaces/IValidationPlugin.sol";
import "./interfaces/IExecutionPlugin.sol";

/**
 * @title MultiSigPlugin
 * @notice ERC-6900 compliant multi-signature plugin for modular smart accounts
 * @dev Implements validation and execution logic for multi-signature operations
 */
contract MultiSigPlugin is IPlugin, IValidationPlugin, IExecutionPlugin {
    // ===================== Structs =====================
    
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
        uint256 timestamp;
        bytes32 txHash;
    }
    
    struct AccountConfig {
        address[] owners;
        mapping(address => bool) isOwner;
        uint256 threshold;
        uint256 transactionCount;
        bool initialized;
    }
    
    // ===================== State Variables =====================
    
    // Account => Configuration
    mapping(address => AccountConfig) private accountConfigs;
    
    // Account => Transaction ID => Transaction
    mapping(address => mapping(uint256 => Transaction)) public transactions;
    
    // Account => Transaction ID => Owner => Confirmed
    mapping(address => mapping(uint256 => mapping(address => bool))) public confirmations;
    
    // Account => Owner => List of transaction IDs
    mapping(address => mapping(address => uint256[])) public ownerTransactions;
    
    // ===================== Events =====================
    
    event PluginInstalled(address indexed account, address[] owners, uint256 threshold);
    event PluginUninstalled(address indexed account);
    event OwnerAdded(address indexed account, address indexed owner);
    event OwnerRemoved(address indexed account, address indexed owner);
    event ThresholdChanged(address indexed account, uint256 oldThreshold, uint256 newThreshold);
    event TransactionSubmitted(
        address indexed account, 
        uint256 indexed txId, 
        address indexed submitter,
        address to,
        uint256 value,
        bytes data
    );
    event TransactionConfirmed(address indexed account, uint256 indexed txId, address indexed owner);
    event ConfirmationRevoked(address indexed account, uint256 indexed txId, address indexed owner);
    event TransactionExecuted(address indexed account, uint256 indexed txId, bool success);
    event TransactionFailed(address indexed account, uint256 indexed txId, bytes reason);
    
    // ===================== Modifiers =====================
    
    modifier onlyOwner(address account) {
        require(accountConfigs[account].isOwner[msg.sender], "Not an owner");
        _;
    }
    
    modifier txExists(address account, uint256 txId) {
        require(transactions[account][txId].to != address(0), "Transaction does not exist");
        _;
    }
    
    modifier notExecuted(address account, uint256 txId) {
        require(!transactions[account][txId].executed, "Transaction already executed");
        _;
    }
    
    modifier notConfirmed(address account, uint256 txId) {
        require(!confirmations[account][txId][msg.sender], "Transaction already confirmed");
        _;
    }
    
    // ===================== Plugin Installation =====================
    
    /**
     * @notice Install the plugin with initial configuration
     * @param data Encoded owners array and threshold
     */
    function onInstall(bytes calldata data) external override {
        require(!accountConfigs[msg.sender].initialized, "Already initialized");
        
        (address[] memory owners, uint256 threshold) = abi.decode(data, (address[], uint256));
        _validateOwnersAndThreshold(owners, threshold);
        
        AccountConfig storage config = accountConfigs[msg.sender];
        config.threshold = threshold;
        config.initialized = true;
        
        for (uint256 i = 0; i < owners.length; i++) {
            address owner = owners[i];
            require(owner != address(0), "Invalid owner address");
            require(!config.isOwner[owner], "Duplicate owner");
            
            config.owners.push(owner);
            config.isOwner[owner] = true;
        }
        
        emit PluginInstalled(msg.sender, owners, threshold);
    }
    
    /**
     * @notice Uninstall the plugin and clean up storage
     * @param data Unused parameter for interface compliance
     */
    function onUninstall(bytes calldata data) external override {
        AccountConfig storage config = accountConfigs[msg.sender];
        require(config.initialized, "Not initialized");
        
        // Clean up owners
        for (uint256 i = 0; i < config.owners.length; i++) {
            delete config.isOwner[config.owners[i]];
        }
        delete config.owners;
        
        // Clean up transactions
        for (uint256 i = 0; i < config.transactionCount; i++) {
            delete transactions[msg.sender][i];
        }
        
        delete accountConfigs[msg.sender];
        emit PluginUninstalled(msg.sender);
    }
    
    // ===================== Validation Functions =====================
    
    /**
     * @notice Validate a user operation for multi-sig requirements
     * @param userOp The user operation to validate
     * @param userOpHash Hash of the user operation
     * @return validationData 0 for success, 1 for failure
     */
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash
    ) external view override returns (uint256 validationData) {
        // Decode multi-sig validation data from signature
        (uint256 txId, address[] memory signers) = abi.decode(
            userOp.signature,
            (uint256, address[])
        );
        
        AccountConfig storage config = accountConfigs[userOp.sender];
        Transaction storage txn = transactions[userOp.sender][txId];
        
        // Verify transaction exists and matches
        if (txn.to == address(0) || txn.executed) {
            return 1; // Invalid
        }
        
        // Verify operation matches transaction
        bytes32 expectedHash = keccak256(abi.encode(txn.to, txn.value, txn.data));
        bytes32 actualHash = keccak256(userOp.callData);
        if (expectedHash != actualHash) {
            return 1; // Mismatch
        }
        
        // Count valid signatures
        uint256 validSignatures = 0;
        for (uint256 i = 0; i < signers.length; i++) {
            if (config.isOwner[signers[i]] && confirmations[userOp.sender][txId][signers[i]]) {
                validSignatures++;
            }
        }
        
        return validSignatures >= config.threshold ? 0 : 1;
    }
    
    // ===================== Transaction Management =====================
    
    /**
     * @notice Submit a new transaction for multi-sig approval
     * @param to Destination address
     * @param value ETH value to send
     * @param data Transaction data
     * @return txId Transaction ID
     */
    function submitTransaction(
        address to,
        uint256 value,
        bytes calldata data
    ) external onlyOwner(msg.sender) returns (uint256 txId) {
        require(to != address(0), "Invalid destination");
        
        AccountConfig storage config = accountConfigs[msg.sender];
        txId = config.transactionCount;
        
        transactions[msg.sender][txId] = Transaction({
            to: to,
            value: value,
            data: data,
            executed: false,
            confirmations: 0,
            timestamp: block.timestamp,
            txHash: keccak256(abi.encode(msg.sender, txId, to, value, data))
        });
        
        config.transactionCount++;
        
        emit TransactionSubmitted(msg.sender, txId, tx.origin, to, value, data);
        
        // Auto-confirm for submitter
        _confirmTransaction(msg.sender, txId);
    }
    
    /**
     * @notice Confirm a pending transaction
     * @param txId Transaction ID to confirm
     */
    function confirmTransaction(uint256 txId) 
        external 
        onlyOwner(msg.sender)
        txExists(msg.sender, txId)
        notExecuted(msg.sender, txId)
        notConfirmed(msg.sender, txId)
    {
        _confirmTransaction(msg.sender, txId);
    }
    
    /**
     * @notice Revoke a confirmation
     * @param txId Transaction ID
     */
    function revokeConfirmation(uint256 txId)
        external
        onlyOwner(msg.sender)
        txExists(msg.sender, txId)
        notExecuted(msg.sender, txId)
    {
        require(confirmations[msg.sender][txId][tx.origin], "Not confirmed");
        
        confirmations[msg.sender][txId][tx.origin] = false;
        transactions[msg.sender][txId].confirmations--;
        
        emit ConfirmationRevoked(msg.sender, txId, tx.origin);
    }
    
    /**
     * @notice Execute a confirmed transaction
     * @param txId Transaction ID to execute
     */
    function executeTransaction(uint256 txId)
        external
        onlyOwner(msg.sender)
        txExists(msg.sender, txId)
        notExecuted(msg.sender, txId)
    {
        Transaction storage txn = transactions[msg.sender][txId];
        AccountConfig storage config = accountConfigs[msg.sender];
        
        require(txn.confirmations >= config.threshold, "Insufficient confirmations");
        
        txn.executed = true;
        
        (bool success, bytes memory result) = txn.to.call{value: txn.value}(txn.data);
        
        if (success) {
            emit TransactionExecuted(msg.sender, txId, true);
        } else {
            emit TransactionFailed(msg.sender, txId, result);
            // Revert the execution status to allow retry
            txn.executed = false;
        }
    }
    
    // ===================== Owner Management =====================
    
    /**
     * @notice Add a new owner
     * @param owner Address to add as owner
     */
    function addOwner(address owner) external onlyOwner(msg.sender) {
        require(owner != address(0), "Invalid owner");
        
        AccountConfig storage config = accountConfigs[msg.sender];
        require(!config.isOwner[owner], "Already an owner");
        
        config.owners.push(owner);
        config.isOwner[owner] = true;
        
        emit OwnerAdded(msg.sender, owner);
    }
    
    /**
     * @notice Remove an existing owner
     * @param owner Address to remove
     */
    function removeOwner(address owner) external onlyOwner(msg.sender) {
        AccountConfig storage config = accountConfigs[msg.sender];
        require(config.isOwner[owner], "Not an owner");
        require(config.owners.length - 1 >= config.threshold, "Would break threshold");
        
        config.isOwner[owner] = false;
        
        // Remove from array
        for (uint256 i = 0; i < config.owners.length; i++) {
            if (config.owners[i] == owner) {
                config.owners[i] = config.owners[config.owners.length - 1];
                config.owners.pop();
                break;
            }
        }
        
        emit OwnerRemoved(msg.sender, owner);
    }
    
    /**
     * @notice Change the confirmation threshold
     * @param newThreshold New threshold value
     */
    function changeThreshold(uint256 newThreshold) external onlyOwner(msg.sender) {
        AccountConfig storage config = accountConfigs[msg.sender];
        _validateOwnersAndThreshold(config.owners, newThreshold);
        
        uint256 oldThreshold = config.threshold;
        config.threshold = newThreshold;
        
        emit ThresholdChanged(msg.sender, oldThreshold, newThreshold);
    }
    
    // ===================== View Functions =====================
    
    /**
     * @notice Get account configuration
     * @param account Account address
     * @return owners Array of owner addresses
     * @return threshold Confirmation threshold
     */
    function getAccountConfig(address account) 
        external 
        view 
        returns (address[] memory owners, uint256 threshold) 
    {
        AccountConfig storage config = accountConfigs[account];
        return (config.owners, config.threshold);
    }
    
    /**
     * @notice Get transaction details
     * @param account Account address
     * @param txId Transaction ID
     * @return Transaction details
     */
    function getTransaction(address account, uint256 txId) 
        external 
        view 
        returns (Transaction memory) 
    {
        return transactions[account][txId];
    }
    
    /**
     * @notice Get transaction confirmations
     * @param account Account address
     * @param txId Transaction ID
     * @return confirmedOwners List of owners who confirmed
     */
    function getConfirmations(address account, uint256 txId)
        external
        view
        returns (address[] memory confirmedOwners)
    {
        AccountConfig storage config = accountConfigs[account];
        uint256 count = 0;
        
        // Count confirmations
        for (uint256 i = 0; i < config.owners.length; i++) {
            if (confirmations[account][txId][config.owners[i]]) {
                count++;
            }
        }
        
        // Build array
        confirmedOwners = new address[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < config.owners.length; i++) {
            if (confirmations[account][txId][config.owners[i]]) {
                confirmedOwners[index] = config.owners[i];
                index++;
            }
        }
    }
    
    /**
     * @notice Check if an address is an owner
     * @param account Account address
     * @param owner Address to check
     * @return bool True if owner
     */
    function isOwner(address account, address owner) external view returns (bool) {
        return accountConfigs[account].isOwner[owner];
    }
    
    /**
     * @notice Get pending transactions for an account
     * @param account Account address
     * @return pendingTxIds Array of pending transaction IDs
     */
    function getPendingTransactions(address account) 
        external 
        view 
        returns (uint256[] memory pendingTxIds) 
    {
        AccountConfig storage config = accountConfigs[account];
        uint256 pendingCount = 0;
        
        // Count pending transactions
        for (uint256 i = 0; i < config.transactionCount; i++) {
            if (!transactions[account][i].executed && transactions[account][i].to != address(0)) {
                pendingCount++;
            }
        }
        
        // Build array
        pendingTxIds = new uint256[](pendingCount);
        uint256 index = 0;
        for (uint256 i = 0; i < config.transactionCount; i++) {
            if (!transactions[account][i].executed && transactions[account][i].to != address(0)) {
                pendingTxIds[index] = i;
                index++;
            }
        }
    }
    
    // ===================== Internal Functions =====================
    
    function _confirmTransaction(address account, uint256 txId) internal {
        confirmations[account][txId][tx.origin] = true;
        transactions[account][txId].confirmations++;
        ownerTransactions[account][tx.origin].push(txId);
        
        emit TransactionConfirmed(account, txId, tx.origin);
    }
    
    function _validateOwnersAndThreshold(
        address[] memory owners,
        uint256 threshold
    ) internal pure {
        require(owners.length > 0, "No owners");
        require(threshold > 0, "Invalid threshold");
        require(threshold <= owners.length, "Threshold too high");
    }
}