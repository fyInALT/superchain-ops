// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {IProxyAdmin} from "@eth-optimism-bedrock/interfaces/universal/IProxyAdmin.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {stdToml} from "forge-std/StdToml.sol";
import {LibString} from "solady/utils/LibString.sol";
import {console} from "forge-std/console.sol";

import {JsonTxsExecutorTaskBase} from "src/improvements/tasks/types/JsonTxsExecutorTaskBase.sol";
import {Action} from "src/libraries/MultisigTypes.sol";
import {StorageSetter} from "@eth-optimism-bedrock/src/universal/StorageSetter.sol";
import {SuperchainAddressRegistry} from "src/improvements/SuperchainAddressRegistry.sol";

/// @notice Template contract for upgrade op from v1.3.0 to v1.8.0 by run json txs generated from upgrade scripts.
contract UpgradeV130toV180 is JsonTxsExecutorTaskBase {
    using stdToml for string;
    using LibString for string;

    mapping(uint256 => address) private _codeExceptionsForUpgrade;
    uint256 private _codeExceptionsForUpgradeCount;

    /// @notice Returns the parent multisig address string identifier
    /// the parent multisig address should be same for all the l2chains in the task
    /// @return The string "ProxyAdminOwner"
    function safeAddressString() public pure override returns (string memory) {
        return "ProxyAdminOwner";
    }

    /// @notice Sets up the template with implementation configurations from a TOML file.
    function _templateSetup(string memory taskConfigFilePath, address rootSafe) internal override {
        super._templateSetup(taskConfigFilePath, rootSafe);
        string memory tomlContent = vm.readFile(taskConfigFilePath);

        SuperchainAddressRegistry.ChainInfo[] memory chains = superchainAddrRegistry.getChains();
        _codeExceptionsForUpgradeCount = 0;

        for (uint256 i = 0; i < chains.length; i++) {
            uint256 chainId = chains[i].chainId;
    
            ISystemConfigProxy systemConfigProxy = ISystemConfigProxy(superchainAddrRegistry.getAddress("SystemConfigProxy", chainId));
            
            address systemConfigOwner = systemConfigProxy.owner();
            _codeExceptionsForUpgrade[_codeExceptionsForUpgradeCount] = systemConfigOwner;
            _codeExceptionsForUpgradeCount += 1;

            bytes32 batcherHash = systemConfigProxy.batcherHash();
            _codeExceptionsForUpgrade[_codeExceptionsForUpgradeCount] =  address(uint160(uint256(batcherHash)));
            _codeExceptionsForUpgradeCount += 1;

            address unsafeBlockSigner = systemConfigProxy.unsafeBlockSigner();
            _codeExceptionsForUpgrade[_codeExceptionsForUpgradeCount] =  unsafeBlockSigner;
            _codeExceptionsForUpgradeCount += 1;

            address batchInbox = systemConfigProxy.batchInbox();
            _codeExceptionsForUpgrade[_codeExceptionsForUpgradeCount] =  batchInbox;
            _codeExceptionsForUpgradeCount += 1;
        }

    }

    /// @notice Returns the storage write permissions required for this task.
    function _taskStorageWrites() internal view virtual override returns (string[] memory) {
        string[] memory storageWrites = new string[](7);
        storageWrites[0] = "OptimismPortalProxy";
        storageWrites[1] = "SystemConfigProxy";
        storageWrites[2] = "AddressManager";
        storageWrites[3] = "L1CrossDomainMessengerProxy";
        storageWrites[4] = "L1StandardBridgeProxy";
        storageWrites[5] = "L1ERC721BridgeProxy";
        storageWrites[6] = "OptimismMintableERC20FactoryProxy";
        return storageWrites;
    }

    /// @notice Override to return a list of addresses that should not be checked for code length.
    function _getCodeExceptions() internal view override returns (address[] memory) {
        address[] memory codeExceptions = new address[](_codeExceptionsForUpgradeCount);
        
        for (uint256 i = 0; i < _codeExceptionsForUpgradeCount; i++) {
            codeExceptions[i] = _codeExceptionsForUpgrade[i];
        }

        return codeExceptions;
    }

    /// @notice Validates that the owner was transferred correctly.
    function _validate(VmSafe.AccountAccess[] memory, Action[] memory, address) internal view override {}
}

interface IOwnable {
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;
}

interface ISystemConfigProxy is IOwnable {
    function batchInbox() external view returns (address addr_);
    function batcherHash() external view returns (bytes32);
    function unsafeBlockSigner() external view returns (address);
}