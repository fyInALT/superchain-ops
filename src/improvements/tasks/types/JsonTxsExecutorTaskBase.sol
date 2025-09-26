// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {IMulticall3} from "forge-std/interfaces/IMulticall3.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {stdToml} from "forge-std/StdToml.sol";
import {StdStyle} from "forge-std/StdStyle.sol";
import {Vm, VmSafe} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";
import {MultisigTaskPrinter} from "src/libraries/MultisigTaskPrinter.sol";
import {MultisigTask, AddressRegistry} from "src/improvements/tasks/MultisigTask.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {SuperchainAddressRegistry} from "src/improvements/SuperchainAddressRegistry.sol";
import {IGnosisSafe} from "@base-contracts/script/universal/IGnosisSafe.sol";
import {L2TaskBase} from "src/improvements/tasks/types/L2TaskBase.sol";
import {Action, TaskType, TaskPayload} from "src/libraries/MultisigTypes.sol";

/// @notice This contract is used for all simple task types. It overrides various functions in the MultisigTask contract.
abstract contract JsonTxsExecutorTaskBase is L2TaskBase {
    using EnumerableSet for EnumerableSet.AddressSet;
    using stdToml for string;
    using StdStyle for string;

    mapping(uint256 => IMulticall3.Call3) private idxToTxCall;
    uint256 private txCallsCount;

    /// @notice Returns the type of task. JsonTxsExecutorTaskBase.
    /// Overrides the taskType function in the MultisigTask contract.
    function taskType() public pure override returns (TaskType) {
        return TaskType.JsonTxsExecutorTaskBase;
    }

    /// @notice Returns the parent multisig address string identifier
    /// the parent multisig address should be same for all the l2chains in the task
    /// @return The string "ProxyAdminOwner"
    function safeAddressString() public pure override returns (string memory) {
        return "ProxyAdminOwner";
    }

    /// @notice Configures the task for JsonTxsExecutorTaskBase type tasks.
    /// Overrides the configureTask function in the MultisigTask contract.
    /// For JsonTxsExecutorTaskBase, we need to configure the simple address registry.
    function _configureTask(string memory taskConfigFilePath) internal override
        returns (
            AddressRegistry addrRegistry_,
            IGnosisSafe parentMultisig_,
            address multicallTarget_
        )
    {
        // The only thing we change is overriding the multicall target.
        (addrRegistry_, parentMultisig_, multicallTarget_) = super
            ._configureTask(taskConfigFilePath);

        string memory toml = vm.readFile(taskConfigFilePath);
        string memory txsJsonPath = toml.readStringOr(".txsJsonPath", "");
        console.log("Reading transaction bundle %s", txsJsonPath);
        string memory json = vm.readFile(txsJsonPath);
        _buildCallsFromJson(json);
    }

    function _build(address rootSafe) internal override {
        for (uint256 i = 0; i < txCallsCount; i++) {
            _runCall3(idxToTxCall[i]);
        }
    }

    function _runCall3(IMulticall3.Call3 memory call3) internal {
        (bool success, ) = address(call3.target).call(call3.callData);
        require(success, "call tx in txs from json failed");
    }

    /// @notice Prank as the multisig.
    function _prankMultisig(address rootSafe) internal override {
        // If delegateCall value is true then sets msg.sender for all subsequent delegate calls.
        // We want this functionality for OPCM tasks.
        vm.startPrank(rootSafe, true);
    }

    /// @notice Get the calldata to be executed by the root safe.
    /// This function uses aggregate3 instead of aggregate3Value because OPCM tasks use Multicall3DelegateCall.
    function _getMulticall3Calldata(Action[] memory actions) internal pure override returns (bytes memory data) {
        (address[] memory targets, , bytes[] memory arguments) = processTaskActions(actions);
    
        IMulticall3.Call3[] memory calls = new IMulticall3.Call3[](targets.length);

        for (uint256 i; i < calls.length; i++) {
            require(targets[i] != address(0), "Invalid target for multisig");
            calls[i] = IMulticall3.Call3({
                target: targets[i],
                allowFailure: false,
                callData: arguments[i]
            });
        }

        data = abi.encodeCall(IMulticall3.aggregate3, (calls));
    }

    /// @notice this function must be overridden in the inheriting contract to run assertions on the state changes.
    function _validate(
        VmSafe.AccountAccess[] memory accountAccesses,
        Action[] memory actions,
        address rootSafe
    ) internal view virtual override {
        accountAccesses; // No-ops to silence unused variable compiler warnings.
        actions;
        rootSafe;
        require(false, "You must implement the _validate function");
    }

    function _buildCallsFromJson(string memory jsonContent) internal {
        // A hacky way to get the total number of elements in a JSON
        // object array because Forge does not support this natively.
        uint256 MAX_LENGTH_SUPPORTED = 999;
        uint256 transaction_count = MAX_LENGTH_SUPPORTED;
        for (uint256 i = 0; transaction_count == MAX_LENGTH_SUPPORTED; i++) {
            require(
                i < MAX_LENGTH_SUPPORTED,
                "Transaction list longer than MAX_LENGTH_SUPPORTED is not "
                "supported, to support it, simply bump the value of "
                "MAX_LENGTH_SUPPORTED to a bigger one."
            );

            try
                vm.parseJsonAddress(
                    jsonContent,
                    string(abi.encodePacked("$.transactions[",vm.toString(i),"].to"))
                )
            returns (address) {} catch {
                transaction_count = i;
            }
        }

        txCallsCount = transaction_count;
        for (uint256 i = 0; i < transaction_count; i++) {
            idxToTxCall[i] = IMulticall3.Call3({
                target: stdJson.readAddress(
                    jsonContent,
                    string(abi.encodePacked("$.transactions[",vm.toString(i),"].to"))
                ),
                allowFailure: false,
                callData: stdJson.readBytes(
                    jsonContent,
                    string(abi.encodePacked("$.transactions[",vm.toString(i),"].data"))
                )
            });
        }
    }
}
