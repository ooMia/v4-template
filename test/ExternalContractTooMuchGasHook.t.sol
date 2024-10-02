// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {BeforeSwapDelta} from "v4-core/src/types/BeforeSwapDelta.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {Counter} from "src/Counter.sol";
import {CounterTest} from "test/Counter.t.sol";

contract ExternalContractTooMuchGasHook is Counter {
    TooMuchGasContract tooMuchGasContract;

    constructor(IPoolManager _poolManager) Counter(_poolManager) {
        tooMuchGasContract = new TooMuchGasContract();
    }

    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata data
    ) public override returns (bytes4, BeforeSwapDelta, uint24) {
        tooMuchGasContract.costTooMuchGas();
        return super.beforeSwap(sender, key, params, data);
    }
}

contract TooMuchGasContract {
    uint256 private tmp;

    function costTooMuchGas() public {
        for (uint256 i = 0; i < 1e6; i++) {
            tmp += i;
        }
    }
}

// forge test --match-test TooMuchGas -vvv
contract ExternalContractTooMuchGasHookTest is CounterTest {
    ExternalContractTooMuchGasHook externalContractTooMuchGasHook;

    function setting() public override {
        // Deploy the hook to an address with the correct flags
        address flags = address(
            uint160(
                Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
                    | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
            ) ^ (0x4444 << 144) // Namespace the hook to avoid collisions
        );
        bytes memory constructorArgs = abi.encode(manager); //Add all the necessary constructor arguments from the hook
        deployCodeTo("test/ExternalContractTooMuchGasHook.t.sol:ExternalContractTooMuchGasHook", constructorArgs, flags);
        hook = flags;
        externalContractTooMuchGasHook = ExternalContractTooMuchGasHook(hook);
        counter = Counter(hook);
    }

    function testExternalContractTooMuchGasHook() public {
        super.testCounterHooks();
    }
}
