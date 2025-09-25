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

/// @notice Template contract for run json txs without check
contract JsonTxsExecutorExample is JsonTxsExecutorTaskBase {
    using stdToml for string;
    using LibString for string;

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
    function _getCodeExceptions() internal pure override returns (address[] memory) {
        address[] memory codeExceptions = new address[](4);
        codeExceptions[0] = 0x2775E29cAE1a4C8B09419ba6E1A96fc48E9AacE1;
        codeExceptions[1] = address(uint160(0x000000000000000000000000376faed5d58f70807efaa47fc24ea489a65d6897));
        codeExceptions[2] = address(uint160(0x000000000000000000000000cf5d8c6e6f4f04e64662dfe3bfa8bb7450f775b4));
        codeExceptions[3] = address(uint160(0x000000000000000000000000ff00000000000000000000000000000000012d3d));
        return codeExceptions;
    }

    /// @notice Validates that the owner was transferred correctly.
    function _validate(VmSafe.AccountAccess[] memory, Action[] memory, address) internal view override {}
}