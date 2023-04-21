// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.13;

import "../src/UniswapV2Router02.sol";
import "../src/UniswapV2Pair.sol";
import "../src/UniswapV2Factory.sol";
import "./utils/WETH10.sol";
import "./BaseSetup.t.sol";

contract RouterTest is BaseSetup {
    UniswapV2Factory public factory = new UniswapV2Factory(alice);
    WETH10 weth = new WETH10();
    UniswapV2Router02 public router;

    

    function setUp() public virtual override {
        BaseSetup.setUp();
        // replace the below bytecode inside the UniswapV2Library.pairFor()
        // string memory pairByteCode = utils.getPairByteCode();
        tokens[0].mint(alice, 10e20);
        tokens[1].mint(alice, 10e20);
        tokens[2].mint(alice, 10e20);
        router = new UniswapV2Router02(address(factory), address(weth));

        tokenA.mint(address(this), 20 ether);
        tokenB.mint(address(this), 20 ether);
        tokenC.mint(address(this), 20 ether);

        emit log_named_bytes32(
            "factory code hash",
                keccak256(abi.encodePacked(type(UniswapV2Pair).creationCode))
        );
    }

    //
    function mockAddLiquidity(address tokenA, address tokenB, uint256 amountADesired,
    uint256 amountBDesired, uint256 amountAMin, uint256 amountBMin) public {
        vm.startPrank(alice);
        IUniswapV2ERC20(tokenA).approve(address(router),type(uint256).max);
        IUniswapV2ERC20(tokenB).approve(address(router),type(uint256).max);
        router.addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin, alice, block.timestamp+200);
        vm.stopPrank();
    }


    function testAddLiquidity() public {
        address token2 = address(tokens[2]);
        mockAddLiquidity(token0, token2, 2e3, 2e3, 1e3, 1e3);
        address pair = UniswapV2Library.pairFor(address(factory), token0, token2);
        assertEq(UniswapV2ERC20(pair).balanceOf(alice), 1000);
        
    }

    function testSequentAddLiquidity() public {
        mockAddLiquidity(token0, token1, 2e3, 2e3, 0, 0);
        uint256 balance0before = ERC20(token0).balanceOf(alice);
        uint256 balance1before = ERC20(token1).balanceOf(alice);
        mockAddLiquidity(token1, token0, 1e3, 2e3, 0, 0);
        address pair = UniswapV2Library.pairFor(address(factory), token0, token1);
        assertEq(UniswapV2ERC20(pair).balanceOf(alice), 2000);
        assertEq(balance0before-1e3, IERC20(token0).balanceOf(alice));
        assertEq(balance0before-1e3, IERC20(token1).balanceOf(alice));
    }

    function testAddLiquidityETH() public {
        vm.startPrank(alice);
        IUniswapV2ERC20(token0).approve(address(router),type(uint256).max);
        (bool success, bytes memory result) = address(router).call{value: 2e-15 ether}(
            abi.encodeWithSignature(
        "addLiquidityETH(address,uint256,uint256,uint256,address,uint256)", token0, 2e3, 0, 0, alice, block.timestamp+200)
        );
        vm.stopPrank();
        assert(success);
        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = abi.decode(result, (uint256, uint256, uint256));
        assertEq(amountToken, 2e3);
        assertEq(amountETH, 2e3);
        assertEq(liquidity, 1e3);
    }

    function testRemoveLiquidity() public {
        mockAddLiquidity(token0, token1, 2e3, 2e3, 0, 0);
        address pair = UniswapV2Library.pairFor(address(factory), token0, token1);
        uint256 balance0before = ERC20(token0).balanceOf(alice);
        uint256 balance1before = ERC20(token1).balanceOf(alice);
        vm.startPrank(alice);
        IUniswapV2ERC20(pair).approve(address(router),type(uint256).max);
        router.removeLiquidity(token0, token1, 100, 0, 0 , alice, block.timestamp+200);
        assertEq(UniswapV2ERC20(pair).balanceOf(alice), 900);
        assertEq(balance0before+100, IERC20(token0).balanceOf(alice));
        assertEq(balance0before+100, IERC20(token1).balanceOf(alice));
    }

    function testRemoveLiquidityETH() public {
        vm.startPrank(alice);
        IUniswapV2ERC20(token0).approve(address(router),type(uint256).max);
        (bool success, bytes memory result) = address(router).call{value: 2e-15 ether}(
            abi.encodeWithSignature(
                "addLiquidityETH(address,uint256,uint256,uint256,address,uint256)", token0, 2e3, 0, 0, alice, block.timestamp+20)
        );
        address pair = UniswapV2Library.pairFor(address(factory), token0, address(weth));
        uint256 balance0before = ERC20(token0).balanceOf(alice);
        uint256 balancebefore = alice.balance;
        console.log(balancebefore);
        IUniswapV2ERC20(pair).approve(address(router),type(uint256).max);
        router.removeLiquidityETH(token0, 100, 0, 0 , alice, block.timestamp+20);
        assertEq(UniswapV2ERC20(pair).balanceOf(alice), 900);
        assertEq(balance0before+100, IERC20(token0).balanceOf(alice));
        assertEq(balancebefore+100, alice.balance);
    }

    

    

    function testAddLiquidityAmountBOptimalIsOk() public {
        address pairAddress = factory.createPair(
            address(tokenA),
            address(tokenB)
        );

        UniswapV2Pair pair = UniswapV2Pair(pairAddress);


        tokenA.transfer(pairAddress, 1 ether);
        tokenB.transfer(pairAddress, 2 ether);
        pair.mint(address(this));

        tokenA.approve(address(router), 1 ether);
        tokenB.approve(address(router), 2 ether);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = router
            .addLiquidity(
                address(tokenA),
                address(tokenB),
                1 ether,
                2 ether,
                1 ether,
                1.9 ether,
                address(this),
                block.timestamp+200
            );

    }

    function testAddLiquidityAmountBOptimalIsTooLow() public {
        address pairAddress = factory.createPair(
            address(tokenA),
            address(tokenB)
        );

        UniswapV2Pair pair = UniswapV2Pair(pairAddress);

        tokenA.transfer(pairAddress, 5 ether);
        tokenB.transfer(pairAddress, 10 ether);
        pair.mint(address(this));

        tokenA.approve(address(router), 1 ether);
        tokenB.approve(address(router), 2 ether);

        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1 ether,
            2 ether,
            1 ether,
            2 ether,
            address(this),
             block.timestamp+200
        );
    }

    function testAddLiquidityAmountBOptimalTooHighAmountATooLow() public {
        address pairAddress = factory.createPair(
            address(tokenA),
            address(tokenB)
        );
        UniswapV2Pair pair = UniswapV2Pair(pairAddress);


        tokenA.transfer(pairAddress, 10 ether);
        tokenB.transfer(pairAddress, 5 ether);
        pair.mint(address(this));

        tokenA.approve(address(router), 2 ether);
        tokenB.approve(address(router), 1 ether);

        vm.expectRevert();
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            2 ether,
            0.9 ether,
            2 ether,
            1 ether,
            address(this),
             block.timestamp+200
        );
    }

    function testAddLiquidityAmountBOptimalIsTooHighAmountAOk() public {
        address pairAddress = factory.createPair(
            address(tokenA),
            address(tokenB)
        );
        UniswapV2Pair pair = UniswapV2Pair(pairAddress);


        tokenA.transfer(pairAddress, 10 ether);
        tokenB.transfer(pairAddress, 5 ether);
        pair.mint(address(this));

        tokenA.approve(address(router), 2 ether);
        tokenB.approve(address(router), 1 ether);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = router
            .addLiquidity(
                address(tokenA),
                address(tokenB),
                2 ether,
                0.9 ether,
                1.7 ether,
                1 ether,
                address(this),
                 block.timestamp+200
            );
        assertEq(amountA, 1.8 ether);
        assertEq(amountB, 0.9 ether);
        assertEq(liquidity, 1272792206135785543);
    }

    function testRemoveLiquidity1() public {
        tokenA.approve(address(router), 1 ether);
        tokenB.approve(address(router), 1 ether);

        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this),
             block.timestamp+200
        );

        address pairAddress = factory.getPair(address(tokenA), address(tokenB));
        UniswapV2Pair pair = UniswapV2Pair(pairAddress);
        uint256 liquidity = pair.balanceOf(address(this));

        pair.approve(address(router), liquidity);

        router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            liquidity,
            1 ether - 1000,
            1 ether - 1000,
            address(this),
             block.timestamp+200
        );

        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        assertEq(reserve0, 1000);
        assertEq(reserve1, 1000);
        assertEq(pair.balanceOf(address(this)), 0);
        assertEq(pair.totalSupply(), 1000);
        assertEq(tokenA.balanceOf(address(this)), 20 ether - 1000);
        assertEq(tokenB.balanceOf(address(this)), 20 ether - 1000);
    }

    function testRemoveLiquidityPartially() public {
        tokenA.approve(address(router), 1 ether);
        tokenB.approve(address(router), 1 ether);

        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this),
             block.timestamp+200
        );

        address pairAddress = factory.getPair(address(tokenA), address(tokenB));
        UniswapV2Pair pair = UniswapV2Pair(pairAddress);
        uint256 liquidity = pair.balanceOf(address(this));

        liquidity = (liquidity * 3) / 10;
        pair.approve(address(router), liquidity);

        router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            liquidity,
            0.3 ether - 300,
            0.3 ether - 300,
            address(this),
             block.timestamp+200
        );

        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        assertEq(reserve0, 0.7 ether + 300);
        assertEq(reserve1, 0.7 ether + 300);
        assertEq(pair.balanceOf(address(this)), 0.7 ether - 700);
        assertEq(pair.totalSupply(), 0.7 ether + 300);
        assertEq(tokenA.balanceOf(address(this)), 20 ether - 0.7 ether - 300);
        assertEq(tokenB.balanceOf(address(this)), 20 ether - 0.7 ether - 300);
    }

    function testRemoveLiquidityInsufficientAAmount() public {
        tokenA.approve(address(router), 1 ether);
        tokenB.approve(address(router), 1 ether);

        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this),
             block.timestamp+200
        );

        address pairAddress = factory.getPair(address(tokenA), address(tokenB));
        UniswapV2Pair pair = UniswapV2Pair(pairAddress);
        uint256 liquidity = pair.balanceOf(address(this));

        pair.approve(address(router), liquidity);

        vm.expectRevert();
        router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            liquidity,
            1 ether,
            1 ether - 1000,
            address(this),
             block.timestamp+200
        );
    }

    function testRemoveLiquidityInsufficientBAmount() public {
        tokenA.approve(address(router), 1 ether);
        tokenB.approve(address(router), 1 ether);

        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this),
             block.timestamp+200
        );

        address pairAddress = factory.getPair(address(tokenA), address(tokenB));
        UniswapV2Pair pair = UniswapV2Pair(pairAddress);
        uint256 liquidity = pair.balanceOf(address(this));

        pair.approve(address(router), liquidity);

        
        vm.expectRevert();
        router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            liquidity,
            1 ether - 1000,
            1 ether,
            address(this),
             block.timestamp+200
        );
    }

    function testSwapExactTokensForTokens() public {
        tokenA.approve(address(router), 1 ether);
        tokenB.approve(address(router), 2 ether);
        tokenC.approve(address(router), 1 ether);

        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this),
             block.timestamp+200
        );

        router.addLiquidity(
            address(tokenB),
            address(tokenC),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this),
             block.timestamp+200
        );

        address[] memory path = new address[](3);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        path[2] = address(tokenC);

        tokenA.approve(address(router), 0.3 ether);
        router.swapExactTokensForTokens(
            0.3 ether,
            0.1 ether,
            path,
            address(this),
             block.timestamp+200
        );

        // Swap 0.3 TKNA for ~0.186 TKNB
        assertEq(
            tokenA.balanceOf(address(this)),
            20 ether - 1 ether - 0.3 ether
        );
        assertEq(tokenB.balanceOf(address(this)), 20 ether - 2 ether);
        assertEq(
            tokenC.balanceOf(address(this)),
            20 ether - 1 ether + 0.186691414219734305 ether
        );
    }

    function testSwapTokensForExactTokens() public {
        tokenA.approve(address(router), 1 ether);
        tokenB.approve(address(router), 2 ether);
        tokenC.approve(address(router), 1 ether);

        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this),
             block.timestamp+200
        );

        router.addLiquidity(
            address(tokenB),
            address(tokenC),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this),
             block.timestamp+200
        );

        address[] memory path = new address[](3);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        path[2] = address(tokenC);

        tokenA.approve(address(router), 0.3 ether);
        router.swapTokensForExactTokens(
            0.186691414219734305 ether,
            0.3 ether,
            path,
            address(this),
             block.timestamp+200
        );

        // Swap 0.3 TKNA for ~0.186 TKNB
        assertEq(
            tokenA.balanceOf(address(this)),
            20 ether - 1 ether - 0.3 ether
        );
        assertEq(tokenB.balanceOf(address(this)), 20 ether - 2 ether);
        assertEq(
            tokenC.balanceOf(address(this)),
            20 ether - 1 ether + 0.186691414219734305 ether
        );
    
}

}