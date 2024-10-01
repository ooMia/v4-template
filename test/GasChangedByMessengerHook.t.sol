// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {BeforeSwapDelta} from "v4-core/src/types/BeforeSwapDelta.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {Counter} from "src/Counter.sol";
import {CounterTest} from "test/Counter.t.sol";

contract GasChangedByMessengerHook is Counter {
    uint256 private tmp;

    constructor(IPoolManager _poolManager) Counter(_poolManager) {}

    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata data
    ) public override returns (bytes4, BeforeSwapDelta, uint24) {
        address caller = tx.origin;
        uint256 iter = uint256(uint160(caller) % 1e5);
        for (uint256 i = 0; i < iter; i++) {
            tmp = i;
        }
        return super.beforeSwap(sender, key, params, data);
    }
}

// forge test --match-test TooMuchGas -vvv
contract GasChangedByMessengerHookTest is CounterTest {
    GasChangedByMessengerHook gasChangedByMessengerHook;

    function setting() public override {
        // Deploy the hook to an address with the correct flags
        address flags = address(
            uint160(
                Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
                    | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
            ) ^ (0x4444 << 144) // Namespace the hook to avoid collisions
        );
        bytes memory constructorArgs = abi.encode(manager); //Add all the necessary constructor arguments from the hook
        deployCodeTo("test/GasChangedByMessengerHook.t.sol:GasChangedByMessengerHook", constructorArgs, flags);
        hook = flags;
        gasChangedByMessengerHook = GasChangedByMessengerHook(hook);
        counter = Counter(hook);
        console.log("Hook address: ", address(gasChangedByMessengerHook));
    }

    function testGasChangedByMessengerHook() public {
        super.testCounterHooks();
    }

    function testLowGasMessengerSwap() public {
        uint160 value = type(uint128).max;
        address caller = address(value);
        // caller는 테스트 컨트랙트(periphery)를 경유한다.
        vm.startPrank(address(this), caller);
        super.testCounterHooks();
    }

    function testHighGasMessengerSwap() public {
        uint160 value = type(uint128).min;
        address caller = address(value);
        vm.startPrank(address(this), caller);
        super.testCounterHooks();
    }
}
