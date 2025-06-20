// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IPlugin {
    function onInstall(bytes calldata data) external;
    function onUninstall(bytes calldata data) external;
}
