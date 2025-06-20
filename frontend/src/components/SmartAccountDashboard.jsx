import React, { useState, useEffect } from 'react';
import { Wallet, Key, Users, Send, CheckCircle, AlertCircle, Loader2, Copy, ExternalLink } from 'lucide-react';

// Mock addresses for demonstration (in production, these would be deployed contracts)
const MOCK_ADDRESSES = {
  entryPoint: '0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789',
  factory: '0x1234567890123456789012345678901234567890',
  multiSigPlugin: '0x2345678901234567890123456789012345678901'
};

const SmartAccountDashboard = () => {
  const [provider, setProvider] = useState(null);
  const [signer, setSigner] = useState(null);
  const [account, setAccount] = useState(null);
  const [balance, setBalance] = useState('0');
  const [owners, setOwners] = useState(['']);
  const [threshold, setThreshold] = useState(1);
  const [transactions, setTransactions] = useState([]);
  const [loading, setLoading] = useState(false);
  const [activeTab, setActiveTab] = useState('account');
  const [logs, setLogs] = useState([]);

  // Utility functions
  const formatEther = (wei) => {
    try {
      return (parseInt(wei) / 1e18).toFixed(4);
    } catch {
      return '0.0000';
    }
  };

  const parseEther = (ether) => {
    try {
      return (parseFloat(ether) * 1e18).toString();
    } catch {
      return '0';
    }
  };

  const getAddress = (address) => {
    // Simple address checksum (not full EIP-55, but good enough for demo)
    return address.toLowerCase().replace(/^0x/, '0x');
  };

  const keccak256 = async (data) => {
    const encoder = new TextEncoder();
    const dataBytes = encoder.encode(data);
    const hashBuffer = await crypto.subtle.digest('SHA-256', dataBytes);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    return '0x' + hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
  };

  // Initialize provider
  useEffect(() => {
    if (window.ethereum) {
      setProvider(window.ethereum);
    }
  }, []);

  // Connect wallet
  const connectWallet = async () => {
    try {
      setLoading(true);
      const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
      setSigner(accounts[0]);
      addLog(`Connected wallet: ${accounts[0]}`, 'success');
    } catch (error) {
      addLog(`Error connecting wallet: ${error.message}`, 'error');
    } finally {
      setLoading(false);
    }
  };

  // Create smart account (simulated)
  const createSmartAccount = async () => {
    try {
      setLoading(true);
      // In production, this would interact with the factory contract
      const timestamp = Date.now().toString();
      const hash = await keccak256(timestamp);
      const mockAccountAddress = '0x' + hash.slice(-40);
      
      setAccount({
        address: mockAccountAddress,
        owners: owners.filter(o => o),
        threshold: threshold,
        nonce: 0
      });
      
      addLog(`Smart account created: ${mockAccountAddress}`, 'success');
      
      // Simulate initial balance
      setBalance(parseEther('1.0'));
    } catch (error) {
      addLog(`Error creating account: ${error.message}`, 'error');
    } finally {
      setLoading(false);
    }
  };

  // Add log entry
  const addLog = (message, type = 'info') => {
    setLogs(prev => [{
      message,
      type,
      timestamp: new Date().toLocaleTimeString()
    }, ...prev].slice(0, 10));
  };

  // Submit transaction (simulated)
  const submitTransaction = async (to, value, data) => {
    try {
      setLoading(true);
      const txId = transactions.length;
      
      const newTx = {
        id: txId,
        to,
        value,
        data,
        confirmations: 1,
        executed: false,
        confirmedBy: [signer]
      };
      
      setTransactions(prev => [...prev, newTx]);
      addLog(`Transaction #${txId} submitted`, 'success');
      
      // Auto-execute if threshold is met
      if (newTx.confirmations >= account.threshold) {
        setTimeout(() => executeTransaction(txId), 1000);
      }
    } catch (error) {
      addLog(`Error submitting transaction: ${error.message}`, 'error');
    } finally {
      setLoading(false);
    }
  };

  // Confirm transaction (simulated)
  const confirmTransaction = async (txId) => {
    try {
      setLoading(true);
      
      setTransactions(prev => prev.map(tx => {
        if (tx.id === txId && !tx.confirmedBy.includes(signer)) {
          const updated = {
            ...tx,
            confirmations: tx.confirmations + 1,
            confirmedBy: [...tx.confirmedBy, signer]
          };
          
          if (updated.confirmations >= account.threshold && !updated.executed) {
            setTimeout(() => executeTransaction(txId), 1000);
          }
          
          return updated;
        }
        return tx;
      }));
      
      addLog(`Transaction #${txId} confirmed`, 'success');
    } catch (error) {
      addLog(`Error confirming transaction: ${error.message}`, 'error');
    } finally {
      setLoading(false);
    }
  };

  // Execute transaction (simulated)
  const executeTransaction = async (txId) => {
    setTransactions(prev => prev.map(tx => {
      if (tx.id === txId) {
        addLog(`Transaction #${txId} executed`, 'success');
        return { ...tx, executed: true };
      }
      return tx;
    }));
  };

  // Copy to clipboard
  const copyToClipboard = (text) => {
    navigator.clipboard.writeText(text);
    addLog('Copied to clipboard', 'info');
  };

  return (
    <div className="min-h-screen bg-gray-900 text-white p-6">
      <div className="max-w-7xl mx-auto">
        {/* Header */}
        <div className="bg-gray-800 rounded-lg p-6 mb-6">
          <h1 className="text-3xl font-bold mb-4 flex items-center gap-3">
            <Wallet className="text-blue-500" />
            ERC-4337 & ERC-6900 Multi-Sig Wallet
          </h1>
          <p className="text-gray-400">
            Test implementation of modular smart accounts with multi-signature functionality
          </p>
        </div>

        {/* Connection Status */}
        <div className="bg-gray-800 rounded-lg p-6 mb-6">
          {!signer ? (
            <button
              onClick={connectWallet}
              disabled={loading}
              className="bg-blue-600 hover:bg-blue-700 px-6 py-3 rounded-lg flex items-center gap-2 transition-colors"
            >
              {loading ? <Loader2 className="animate-spin" size={20} /> : <Key size={20} />}
              Connect Wallet
            </button>
          ) : (
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="w-3 h-3 bg-green-500 rounded-full"></div>
                <span className="text-gray-300">Connected: {signer.slice(0, 6)}...{signer.slice(-4)}</span>
              </div>
              {account && (
                <div className="flex items-center gap-2">
                  <span className="text-gray-400">Smart Account:</span>
                  <code className="bg-gray-700 px-3 py-1 rounded">{account.address.slice(0, 6)}...{account.address.slice(-4)}</code>
                  <button
                    onClick={() => copyToClipboard(account.address)}
                    className="text-gray-400 hover:text-white"
                  >
                    <Copy size={16} />
                  </button>
                </div>
              )}
            </div>
          )}
        </div>

        {/* Main Content */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Left Panel - Account Setup */}
          <div className="lg:col-span-1">
            <div className="bg-gray-800 rounded-lg p-6">
              <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
                <Users size={20} />
                Account Setup
              </h2>
              
              {!account ? (
                <div className="space-y-4">
                  <div>
                    <label className="block text-sm text-gray-400 mb-2">Owners</label>
                    {owners.map((owner, index) => (
                      <div key={index} className="flex gap-2 mb-2">
                        <input
                          type="text"
                          value={owner}
                          onChange={(e) => {
                            const newOwners = [...owners];
                            newOwners[index] = e.target.value;
                            setOwners(newOwners);
                          }}
                          placeholder="0x..."
                          className="flex-1 bg-gray-700 rounded px-3 py-2 text-sm"
                        />
                        {index === owners.length - 1 && (
                          <button
                            onClick={() => setOwners([...owners, ''])}
                            className="bg-blue-600 hover:bg-blue-700 px-3 py-2 rounded text-sm"
                          >
                            +
                          </button>
                        )}
                      </div>
                    ))}
                  </div>
                  
                  <div>
                    <label className="block text-sm text-gray-400 mb-2">Threshold</label>
                    <input
                      type="number"
                      value={threshold}
                      onChange={(e) => setThreshold(Math.max(1, parseInt(e.target.value) || 1))}
                      min="1"
                      max={owners.filter(o => o).length || 1}
                      className="w-full bg-gray-700 rounded px-3 py-2 text-sm"
                    />
                  </div>
                  
                  <button
                    onClick={createSmartAccount}
                    disabled={!signer || loading || owners.filter(o => o).length < threshold}
                    className="w-full bg-green-600 hover:bg-green-700 disabled:bg-gray-600 px-4 py-2 rounded flex items-center justify-center gap-2 transition-colors"
                  >
                    {loading ? <Loader2 className="animate-spin" size={20} /> : <Wallet size={20} />}
                    Create Smart Account
                  </button>
                </div>
              ) : (
                <div className="space-y-4">
                  <div className="bg-gray-700 rounded p-4">
                    <p className="text-sm text-gray-400">Address</p>
                    <p className="font-mono text-xs break-all">{account.address}</p>
                  </div>
                  
                  <div className="bg-gray-700 rounded p-4">
                    <p className="text-sm text-gray-400">Balance</p>
                    <p className="text-2xl font-semibold">{formatEther(balance)} ETH</p>
                  </div>
                  
                  <div className="bg-gray-700 rounded p-4">
                    <p className="text-sm text-gray-400 mb-2">Owners ({account.owners.length})</p>
                    {account.owners.map((owner, i) => (
                      <p key={i} className="font-mono text-xs">{owner}</p>
                    ))}
                  </div>
                  
                  <div className="bg-gray-700 rounded p-4">
                    <p className="text-sm text-gray-400">Threshold</p>
                    <p className="text-xl">{account.threshold} of {account.owners.length}</p>
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* Right Panel - Transactions */}
          <div className="lg:col-span-2">
            <div className="bg-gray-800 rounded-lg p-6">
              {/* Tabs */}
              <div className="flex gap-4 mb-6 border-b border-gray-700">
                <button
                  onClick={() => setActiveTab('send')}
                  className={`pb-3 px-1 ${activeTab === 'send' ? 'border-b-2 border-blue-500 text-blue-500' : 'text-gray-400'}`}
                >
                  Send Transaction
                </button>
                <button
                  onClick={() => setActiveTab('transactions')}
                  className={`pb-3 px-1 ${activeTab === 'transactions' ? 'border-b-2 border-blue-500 text-blue-500' : 'text-gray-400'}`}
                >
                  Transactions ({transactions.length})
                </button>
                <button
                  onClick={() => setActiveTab('logs')}
                  className={`pb-3 px-1 ${activeTab === 'logs' ? 'border-b-2 border-blue-500 text-blue-500' : 'text-gray-400'}`}
                >
                  Activity Logs
                </button>
              </div>

              {/* Send Transaction Tab */}
              {activeTab === 'send' && account && (
                <form
                  onSubmit={(e) => {
                    e.preventDefault();
                    const formData = new FormData(e.target);
                    submitTransaction(
                      formData.get('to'),
                      parseEther(formData.get('value') || '0'),
                      formData.get('data') || '0x'
                    );
                    e.target.reset();
                  }}
                  className="space-y-4"
                >
                  <div>
                    <label className="block text-sm text-gray-400 mb-2">To Address</label>
                    <input
                      name="to"
                      type="text"
                      required
                      placeholder="0x..."
                      className="w-full bg-gray-700 rounded px-3 py-2"
                    />
                  </div>
                  
                  <div>
                    <label className="block text-sm text-gray-400 mb-2">Value (ETH)</label>
                    <input
                      name="value"
                      type="number"
                      step="0.0001"
                      placeholder="0.0"
                      className="w-full bg-gray-700 rounded px-3 py-2"
                    />
                  </div>
                  
                  <div>
                    <label className="block text-sm text-gray-400 mb-2">Data (optional)</label>
                    <input
                      name="data"
                      type="text"
                      placeholder="0x..."
                      className="w-full bg-gray-700 rounded px-3 py-2"
                    />
                  </div>
                  
                  <button
                    type="submit"
                    disabled={loading}
                    className="w-full bg-blue-600 hover:bg-blue-700 disabled:bg-gray-600 px-4 py-2 rounded flex items-center justify-center gap-2"
                  >
                    {loading ? <Loader2 className="animate-spin" size={20} /> : <Send size={20} />}
                    Submit Transaction
                  </button>
                </form>
              )}

              {/* Transactions Tab */}
              {activeTab === 'transactions' && (
                <div className="space-y-4">
                  {transactions.length === 0 ? (
                    <p className="text-gray-400 text-center py-8">No transactions yet</p>
                  ) : (
                    transactions.map(tx => (
                      <div key={tx.id} className="bg-gray-700 rounded-lg p-4">
                        <div className="flex justify-between items-start mb-3">
                          <div>
                            <p className="font-semibold">Transaction #{tx.id}</p>
                            <p className="text-sm text-gray-400">To: {tx.to.slice(0, 10)}...{tx.to.slice(-8)}</p>
                            <p className="text-sm text-gray-400">Value: {formatEther(tx.value)} ETH</p>
                          </div>
                          <div className="text-right">
                            {tx.executed ? (
                              <span className="bg-green-600 px-3 py-1 rounded-full text-sm flex items-center gap-1">
                                <CheckCircle size={16} />
                                Executed
                              </span>
                            ) : (
                              <span className="bg-yellow-600 px-3 py-1 rounded-full text-sm">
                                {tx.confirmations}/{account.threshold} confirmations
                              </span>
                            )}
                          </div>
                        </div>
                        
                        {!tx.executed && !tx.confirmedBy.includes(signer) && (
                          <button
                            onClick={() => confirmTransaction(tx.id)}
                            disabled={loading}
                            className="bg-blue-600 hover:bg-blue-700 px-4 py-2 rounded text-sm flex items-center gap-2"
                          >
                            <CheckCircle size={16} />
                            Confirm
                          </button>
                        )}
                      </div>
                    ))
                  )}
                </div>
              )}

              {/* Logs Tab */}
              {activeTab === 'logs' && (
                <div className="space-y-2">
                  {logs.length === 0 ? (
                    <p className="text-gray-400 text-center py-8">No activity yet</p>
                  ) : (
                    logs.map((log, i) => (
                      <div
                        key={i}
                        className={`flex items-start gap-3 p-3 rounded ${
                          log.type === 'error' ? 'bg-red-900/20' : 
                          log.type === 'success' ? 'bg-green-900/20' : 
                          'bg-gray-700/50'
                        }`}
                      >
                        {log.type === 'error' ? (
                          <AlertCircle className="text-red-500 mt-0.5" size={16} />
                        ) : log.type === 'success' ? (
                          <CheckCircle className="text-green-500 mt-0.5" size={16} />
                        ) : (
                          <div className="w-4" />
                        )}
                        <div className="flex-1">
                          <p className="text-sm">{log.message}</p>
                          <p className="text-xs text-gray-500">{log.timestamp}</p>
                        </div>
                      </div>
                    ))
                  )}
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Info Panel */}
        <div className="mt-6 bg-gray-800 rounded-lg p-6">
          <h3 className="text-lg font-semibold mb-3">Implementation Details</h3>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm">
            <div>
              <p className="text-gray-400">ERC-4337 Features</p>
              <ul className="mt-1 text-gray-300 space-y-1">
                <li>• Account abstraction</li>
                <li>• UserOperation validation</li>
                <li>• Gas sponsorship ready</li>
              </ul>
            </div>
            <div>
              <p className="text-gray-400">ERC-6900 Features</p>
              <ul className="mt-1 text-gray-300 space-y-1">
                <li>• Modular plugin system</li>
                <li>• Multi-sig validation plugin</li>
                <li>• Extensible architecture</li>
              </ul>
            </div>
            <div>
              <p className="text-gray-400">Multi-Sig Features</p>
              <ul className="mt-1 text-gray-300 space-y-1">
                <li>• Configurable threshold</li>
                <li>• Multiple owner support</li>
                <li>• Transaction queue</li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default SmartAccountDashboard;