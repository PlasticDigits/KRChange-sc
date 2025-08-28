// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.19;

import "forge-std/Test.sol";

import {AmmFactory} from "src/amm/AmmFactory.sol";
import {AmmRouter01} from "src/amm/AmmRouter01.sol";
import {IAmmPair} from "src/interfaces/IAmmPair.sol";
import {IAmmFactory} from "src/interfaces/IAmmFactory.sol";
import {WETH} from "src/amm/lib/WETH.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MintableMockERC20} from "test/mocks/MintableMockERC20.sol";

contract RouterTradingFeeTest is Test {
    AmmFactory public factory;
    AmmRouter01 public router;
    WETH public weth;

    MintableMockERC20 public tokenA;
    MintableMockERC20 public tokenB;

    address public liquidityProvider = address(0xA11CE);
    address public trader = address(0xB0B);

    IAmmPair public pair;

    uint256 public constant ONE = 1e18;

    function setUp() public {
        factory = new AmmFactory(address(this));
        weth = new WETH();
        router = new AmmRouter01(address(factory), address(weth));

        tokenA = new MintableMockERC20();
        tokenB = new MintableMockERC20();
        tokenA.init("TokenA", "TKA", 18);
        tokenB.init("TokenB", "TKB", 18);

        tokenA.mint(liquidityProvider, 2_000_000 * ONE);
        tokenB.mint(liquidityProvider, 2_000_000 * ONE);
        tokenA.mint(trader, 1_000_000 * ONE);
        tokenB.mint(trader, 1_000_000 * ONE);

        vm.startPrank(liquidityProvider);
        IERC20(address(tokenA)).approve(address(router), type(uint256).max);
        IERC20(address(tokenB)).approve(address(router), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(trader);
        IERC20(address(tokenA)).approve(address(router), type(uint256).max);
        IERC20(address(tokenB)).approve(address(router), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(liquidityProvider);
        router.addLiquidity(
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

        address pairAddr = IAmmFactory(address(factory)).getPair(
            address(tokenA),
            address(tokenB)
        );
        require(pairAddr != address(0), "pair not created");
        pair = IAmmPair(pairAddr);
    }

    function test_tradingFee_default_approx_5_percent() public {
        uint256 amountIn = 1_000 * ONE; // small relative to reserves

        // snapshot reserves before swap
        (uint112 r0, uint112 r1, ) = pair.getReserves();
        (address token0, ) = sort(address(tokenA), address(tokenB));
        bool aIsToken0 = token0 == address(tokenA);
        uint256 reserveIn = aIsToken0 ? uint256(r0) : uint256(r1);
        uint256 reserveOut = aIsToken0 ? uint256(r1) : uint256(r0);

        // compute no-fee expected output using constant product formula
        uint256 outNoFee = getAmountOutNoFee(amountIn, reserveIn, reserveOut);

        // perform swap and capture actual output (fee-included)
        vm.startPrank(trader);
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        uint256[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            0,
            path,
            trader,
            block.timestamp + 1000
        );
        vm.stopPrank();

        uint256 outWithFee = amounts[1];

        // effective fee in bips ~= (noFee - withFee) / noFee * 10000
        uint256 feeBips = ((outNoFee - outWithFee) * 10_000) / outNoFee;
        assertGe(feeBips, 490); // 4.90%
        assertLe(feeBips, 510); // 5.10%
    }

    function test_tradingFee_when_set_to_1_percent() public {
        // set fee to 1%
        factory.setFeeRateBips(100);

        uint256 amountIn = 1_000 * ONE;

        (uint112 r0, uint112 r1, ) = pair.getReserves();
        (address token0, ) = sort(address(tokenA), address(tokenB));
        bool aIsToken0 = token0 == address(tokenA);
        uint256 reserveIn = aIsToken0 ? uint256(r0) : uint256(r1);
        uint256 reserveOut = aIsToken0 ? uint256(r1) : uint256(r0);

        uint256 outNoFee = getAmountOutNoFee(amountIn, reserveIn, reserveOut);

        vm.startPrank(trader);
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        uint256[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            0,
            path,
            trader,
            block.timestamp + 1000
        );
        vm.stopPrank();

        uint256 outWithFee = amounts[1];
        uint256 feeBips = ((outNoFee - outWithFee) * 10_000) / outNoFee;
        assertGe(feeBips, 92); // 0.92%
        assertLe(feeBips, 102); // 1.02%
    }

    function getAmountOutNoFee(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        // Uniswap v2 formula without fee: out = amountIn * reserveOut / (reserveIn + amountIn)
        uint256 numerator = amountIn * reserveOut;
        uint256 denominator = reserveIn + amountIn;
        amountOut = numerator / denominator;
    }

    function sort(
        address a,
        address b
    ) internal pure returns (address, address) {
        return a < b ? (a, b) : (b, a);
    }
}
