// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {AmmFactory} from "src/amm/AmmFactory.sol";
import {AmmRouter01} from "src/amm/AmmRouter01.sol";
import {IAmmPair} from "src/interfaces/IAmmPair.sol";
import {IAmmFactory} from "src/interfaces/IAmmFactory.sol";
import {IWETH} from "src/interfaces/IWETH.sol";
import {WETH} from "src/amm/lib/WETH.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MintableMockERC20} from "test/mocks/MintableMockERC20.sol";

contract RouterSwapFeesTest is Test {
    AmmFactory public factory;
    AmmRouter01 public router;
    WETH public weth;

    MintableMockERC20 public tokenA;
    MintableMockERC20 public tokenB;

    address public liquidityProvider = address(0xA11CE);
    address public trader = address(0xB0B);
    address public feeRecipient = address(0xFEE);

    IAmmPair public pair;

    uint256 public constant ONE = 1e18;

    function setUp() public {
        // Deploy core
        factory = new AmmFactory(address(this));
        weth = new WETH();
        router = new AmmRouter01(address(factory), address(weth));

        // Configure fee recipient explicitly
        factory.setFeeTo(feeRecipient);
        // Keep default feeRateBips (500 bips => 5%) or set explicitly if desired
        // factory.setFeeRateBips(500);

        // Deploy mock ERC20s
        tokenA = new MintableMockERC20();
        tokenB = new MintableMockERC20();
        tokenA.init("TokenA", "TKA", 18);
        tokenB.init("TokenB", "TKB", 18);

        // Mint balances
        tokenA.mint(liquidityProvider, 2_000_000 * ONE);
        tokenB.mint(liquidityProvider, 2_000_000 * ONE);
        tokenA.mint(trader, 1_000_000 * ONE);
        tokenB.mint(trader, 1_000_000 * ONE);

        // LP approves router
        vm.startPrank(liquidityProvider);
        IERC20(address(tokenA)).approve(address(router), type(uint256).max);
        IERC20(address(tokenB)).approve(address(router), type(uint256).max);
        vm.stopPrank();

        // Trader approves router
        vm.startPrank(trader);
        IERC20(address(tokenA)).approve(address(router), type(uint256).max);
        IERC20(address(tokenB)).approve(address(router), type(uint256).max);
        vm.stopPrank();

        // Provide initial liquidity 1,000,000 A : 1,000,000 B
        vm.startPrank(liquidityProvider);
        (uint256 amountAAdded, uint256 amountBAdded, ) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1_000_000 * ONE,
            1_000_000 * ONE,
            0,
            0,
            liquidityProvider,
            block.timestamp + 1000
        );
        vm.stopPrank();

        // Sanity
        assertGt(amountAAdded, 0);
        assertEq(amountAAdded, amountBAdded);

        // Resolve pair
        address pairAddr = IAmmFactory(address(factory)).getPair(
            address(tokenA),
            address(tokenB)
        );
        require(pairAddr != address(0), "pair not created");
        pair = IAmmPair(pairAddr);
    }

    function test_routerSwaps_feeSplitRoughlyHalf() public {
        // Perform swaps via router to accrue fees
        vm.startPrank(trader);
        address[] memory pathAB = new address[](2);
        pathAB[0] = address(tokenA);
        pathAB[1] = address(tokenB);
        address[] memory pathBA = new address[](2);
        pathBA[0] = address(tokenB);
        pathBA[1] = address(tokenA);
        // Use small fixed amounts to minimize price drift but accrue fees over many iterations
        uint256 amountPerSwap = 1_000 * ONE; // 0.1% of reserves per swap initially
        for (uint256 i = 0; i < 100; i++) {
            router.swapExactTokensForTokens(
                amountPerSwap,
                0,
                pathAB,
                trader,
                block.timestamp + 1000
            );
            router.swapExactTokensForTokens(
                amountPerSwap,
                0,
                pathBA,
                trader,
                block.timestamp + 1000
            );
        }
        vm.stopPrank();

        // Trigger fee mint by a small liquidity event (must be >0 after quoting)
        vm.startPrank(liquidityProvider);
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1 * ONE,
            1 * ONE,
            0,
            0,
            liquidityProvider,
            block.timestamp + 1000
        );
        vm.stopPrank();

        // Snapshot pre-burn reserves for valuation
        (uint112 reserve0Before, uint112 reserve1Before, ) = pair.getReserves();
        // token ordering in pair is lexicographic by address. Map reserves to tokenA/tokenB.
        (address token0, ) = sort(address(tokenA), address(tokenB));
        bool aIsToken0 = token0 == address(tokenA);
        uint256 rA = aIsToken0
            ? uint256(reserve0Before)
            : uint256(reserve1Before);
        uint256 rB = aIsToken0
            ? uint256(reserve1Before)
            : uint256(reserve0Before);
        assertGt(rA, 0);
        assertGt(rB, 0);
        console2.log("reserves A,B", rA, rB);

        // Record feeTo LP token balance to ensure it got minted some
        uint256 feeToLpBalance = IERC20(address(pair)).balanceOf(feeRecipient);
        console2.log("feeTo LP balance", feeToLpBalance);
        assertGt(feeToLpBalance, 0);

        // Remove all liquidity from LP and from feeRecipient via router
        uint256 lpBalanceLP = IERC20(address(pair)).balanceOf(
            liquidityProvider
        );
        console2.log("LP LP balance", lpBalanceLP);
        vm.startPrank(liquidityProvider);
        IERC20(address(pair)).approve(address(router), lpBalanceLP);
        (uint256 alice0Out, uint256 alice1Out) = router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            lpBalanceLP,
            0,
            0,
            liquidityProvider,
            block.timestamp + 1000
        );
        vm.stopPrank();

        vm.startPrank(feeRecipient);
        IERC20(address(pair)).approve(address(router), feeToLpBalance);
        (uint256 fee0Out, uint256 fee1Out) = router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            feeToLpBalance,
            0,
            0,
            feeRecipient,
            block.timestamp + 1000
        );
        vm.stopPrank();

        // Determine initial amounts added by LP for baseline
        // For simplicity, we set initial add to 1,000,000 each in setUp
        uint256 initialA = 1_000_000 * ONE;
        uint256 initialB = 1_000_000 * ONE;

        // Value everything in terms of tokenA using price rA/rB at pre-burn snapshot
        // price of 1 tokenB in tokenA terms = rA/rB
        uint256 priceBInA = (rA * 1e18) / rB;
        console2.log("priceBInA (1e18)", priceBInA);

        // LP provider profit in tokenA terms
        uint256 aliceProfitA = 0;
        {
            uint256 aliceARecv = alice0Out;
            uint256 aliceBRecv = alice1Out;
            // Map outputs to actual token symbols since router respects token order
            if (!aIsToken0) {
                // router returned (amountA, amountB) according to input order in removeLiquidity
                // We passed (tokenA, tokenB), so alice0Out is tokenA, alice1Out is tokenB already
            }
            uint256 aliceAFromB = (aliceBRecv * priceBInA) / 1e18;
            // subtract principal
            uint256 principalAInA = initialA + (initialB * priceBInA) / 1e18;
            uint256 totalReturnedInA = aliceARecv + aliceAFromB;
            aliceProfitA = totalReturnedInA > principalAInA
                ? totalReturnedInA - principalAInA
                : 0;
            console2.log(
                "aliceARecv, aliceBRecv, aliceAFromB",
                aliceARecv,
                aliceBRecv,
                aliceAFromB
            );
            console2.log(
                "principalAInA, totalReturnedInA, aliceProfitA",
                principalAInA,
                totalReturnedInA,
                aliceProfitA
            );
        }

        // Fee recipient proceeds in tokenA terms (all proceeds are fees)
        uint256 feeRecipientFeesA = 0;
        {
            uint256 feeARecv = fee0Out;
            uint256 feeBRecv = fee1Out;
            uint256 feeAFromB = (feeBRecv * priceBInA) / 1e18;
            feeRecipientFeesA = feeARecv + feeAFromB;
            console2.log(
                "fee0Out, fee1Out, feeAFromB",
                fee0Out,
                fee1Out,
                feeAFromB
            );
            console2.log("feeRecipientFeesA", feeRecipientFeesA);
        }

        // Both parties should have received some value
        assertGt(aliceProfitA, 0);
        assertGt(feeRecipientFeesA, 0);

        // Check split is roughly 50/50 within 40/60 tolerance
        uint256 totalFeesA = aliceProfitA + feeRecipientFeesA;
        // 40% <= alice share <= 60%
        uint256 aliceShareBips = (aliceProfitA * 10_000) / totalFeesA;
        console2.log("totalFeesA, aliceShareBips", totalFeesA, aliceShareBips);
        assertGe(aliceShareBips, 4000);
        assertLe(aliceShareBips, 6000);
    }

    function sort(
        address a,
        address b
    ) internal pure returns (address, address) {
        return a < b ? (a, b) : (b, a);
    }
}
