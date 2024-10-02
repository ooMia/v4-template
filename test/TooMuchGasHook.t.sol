// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {BeforeSwapDelta} from "v4-core/src/types/BeforeSwapDelta.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {Counter} from "src/Counter.sol";
import {CounterTest} from "test/Counter.t.sol";

contract TooMuchGasHook is Counter {
    uint256 private tmp;

    constructor(IPoolManager _poolManager) Counter(_poolManager) {}

    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata data
    ) public override returns (bytes4, BeforeSwapDelta, uint24) {
        for (uint256 i = 0; i < 1e6; i++) {
            tmp += i;
        }
        return super.beforeSwap(sender, key, params, data);
    }
}

// forge test --match-test TooMuchGas -vvv
contract TooMuchGasHookTest is CounterTest {
    TooMuchGasHook tooMuchGasHook;

    function setting() public override {
        // Deploy the hook to an address with the correct flags
        address flags = address(
            uint160(
                Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
                    | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
            ) ^ (0x4444 << 144) // Namespace the hook to avoid collisions
        );
        bytes memory constructorArgs = abi.encode(manager); //Add all the necessary constructor arguments from the hook
        deployCodeTo("test/TooMuchGasHook.t.sol:TooMuchGasHook", constructorArgs, flags);
        hook = flags;
        tooMuchGasHook = TooMuchGasHook(hook);
        counter = Counter(hook);
    }

    function testTooMuchGasHook() public {
        super.testCounterHooks();
    }
}
