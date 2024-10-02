// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta} from "v4-core/src/types/BeforeSwapDelta.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {Hooks, IHooks} from "v4-core/src/libraries/Hooks.sol";
import {Counter} from "src/Counter.sol";
import {CounterTest} from "test/Counter.t.sol";

import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {EasyPosm} from "./utils/EasyPosm.sol";

contract ZeroFeeHook is Counter {
    uint256 public importantAmountAsset;

    constructor(IPoolManager _poolManager) Counter(_poolManager) {}

    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata data
    ) public override returns (bytes4, BeforeSwapDelta, uint24) {
        importantAmountAsset += 1;
        return super.beforeSwap(sender, key, params, data);
    }
}

// forge test --match-test TooMuchGas -vvv
contract ZeroFeeHookTest is CounterTest {
    using EasyPosm for IPositionManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    ZeroFeeHook zeroFeeHook;

    function setting() public override {
        // Deploy the hook to an address with the correct flags
        address flags = address(
            uint160(
                Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
                    | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
            ) ^ (0x4444 << 144) // Namespace the hook to avoid collisions
        );
        bytes memory constructorArgs = abi.encode(manager); //Add all the necessary constructor arguments from the hook
        deployCodeTo("test/ZeroFeeHook.t.sol:ZeroFeeHook", constructorArgs, flags);
        hook = flags;
        zeroFeeHook = ZeroFeeHook(hook);
        counter = Counter(hook);
    }

    function assignPool() public override {
        // Create the pool
        key = PoolKey(currency0, currency1, 0, 60, IHooks(counter));
        poolId = key.toId();
        manager.initialize(key, SQRT_PRICE_1_1, ZERO_BYTES);
    }

    function setLiquidityAmount() public pure override returns (uint128 amount) {
        amount = type(uint128).max / 1e5;
    }

    function testZeroFeeHook() public {
        int128 amount = -1 ether;

        bool zeroForOne = true;
        BalanceDelta swapDelta = swap(key, zeroForOne, amount, ZERO_BYTES);

        assertEq(amount, swapDelta.amount0(), "delta0");
        assertLt(swapDelta.amount1(), -amount, "delta1");
        console2.log(amount);
        console2.log(swapDelta.amount0());
        console2.log(swapDelta.amount1());
    }

    function testFuzz_zeroFeeHook(int128 amount) public {
        vm.assume(amount > -1e18 && amount < -1e1);

        bool zeroForOne = true;
        BalanceDelta swapDelta = swap(key, zeroForOne, amount, ZERO_BYTES);

        assertEq(amount, swapDelta.amount0(), "delta0");
        assertLt(swapDelta.amount1(), -amount, "delta1");
    }
}
