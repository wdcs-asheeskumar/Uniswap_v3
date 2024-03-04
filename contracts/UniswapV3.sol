//SPDX-License-Identifier:MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import "https://github.com/Uniswap/v3-core/blob/main/contracts/interfaces/IUniswapV3Pool.sol";
import "https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/TickMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721Receiver.sol";
import "https://github.com/Uniswap/v3-periphery/blob/main/contracts/libraries/TransferHelper.sol";
import "https://github.com/Uniswap/v3-periphery/blob/main/contracts/interfaces/INonfungiblePositionManager.sol";
import "https://github.com/Uniswap/v3-periphery/blob/main/contracts/interfaces/ISwapRouter.sol";

// import "https://github.com/Uniswap/v3-core/blob/main/contracts/interfaces/IUniswapV3Factory.sol";

contract UniswapV3 {
    ISwapRouter constant router =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    INonfungiblePositionManager constant positionManager =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    uint24 public constant poolFee = 3000;
    address constant token0 = 0xBBDBbA407bE24E233720680e9ec4228303651Cc9;
    address constant token1 = 0xabfe2ecAde73884D29152a93C1BBD008760DDf6b;

    struct Deposit {
        address owner;
        uint128 liquidity;
        address token0;
        address token1;
    }

    mapping(uint256 => Deposit) public deposits;

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        _createDeposit(operator, tokenId);
        return this.onERC721Received.selector;
    }

    function _createDeposit(address owner, uint256 tokenId) internal {
        (,, address token0, address token1,,,,uint128 liquidity,,,,) = positionManager.positions(tokenId);

        deposits[tokenId] = Deposit({
            owner: owner,
            liquidity: liquidity,
            token0: token0,
            token1: token1
        });
    }

    function mintNewPosition()
        external
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        uint256 amount0ToMint = 1000;
        uint256 amount1ToMint = 1000;

        TransferHelper.safeTransferFrom(token0, msg.sender, address(this), amount0ToMint);
        TransferHelper.safeTransferFrom(token1, msg.sender, address(this), amount1ToMint);

        INonfungiblePositionManager.MintParams memory params = 
            INonfungiblePositionManager.MintParams({
                token0 : token0,
                token1 : token1,
                fee : poolFee,
                tickLower : TickMath.MIN_TICK,
                tickUpper : TickMath.MAX_TICK,
                amount0Desired : amount0ToMint,
                amount1Desired : amount1ToMint,
                amount0Min : 0,
                amount1Min : 0,
                recipient : address(this),
                deadline : block.timestamp
            });

            (tokenId, liquidity, amount0, amount0) = positionManager.mint(params);

            _createDeposit(msg.sender, tokenId);

            if(amount0 < amount0ToMint){
                TransferHelper.safeApprove(token0, address(positionManager), 0);
                uint256 refund0 = amount0ToMint - amount0;
                TransferHelper.safeTransfer(token0, msg.sender, refund0);
            }
            if(amount1 < amount1ToMint){
                TransferHelper.safeApprove(token1, address(positionManager), 0);
                uint256 refund1 = amount1ToMint - amount1;
                TransferHelper.safeTransfer(token1, msg.sender, refund1);
            }
    }

    function collectAllFees(uint256 tokenId) external returns(uint amount0, uint amount1){
        
        INonfungiblePositionManager.CollectParams memory params = 
            INonfungiblePositionManager.CollectParams({
                tokenId : tokenId,
                recipient : address(this),
                amount0Max : type(uint128).max,
                amount1Max : type(uint128).max
            }); 

        (amount0, amount1) = positionManager.collect(params);
        _sendToOwner(tokenId, amount0, amount1);

    }

    function decreaseTheLiquidity(uint tokenId) external returns(uint amount0, uint amount1){
        
        require(msg.sender == deposits[tokenId].owner, "Not the owner");

        uint128 liquidity = deposits[tokenId].liquidity;
        uint128 halfLiquidity = liquidity/2;

        INonfungiblePositionManager.DecreaseLiquidityParams memory params =
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId : tokenId,
                liquidity : halfLiquidity,
                amount0Min : 0,
                amount1Min : 0,
                deadline : block.timestamp
            });
        
        (amount0, amount1) = positionManager.decreaseLiquidity(params);
        _sendToOwner(tokenId, amount0, amount1);

    }

    function _sendToOwner(
        uint256 tokenId, 
        uint256 amount0, 
        uint256 amount1) internal {
        
        address owner = deposits[tokenId].owner;
        
        address token0 = deposits[tokenId].owner;
        address token1 = deposits[tokenId].owner;

        TransferHelper.safeTransfer(token0, owner, amount0);
        TransferHelper.safeTransfer(token1, owner, amount1);
    }

    function retrieveNFT(uint256 tokenId) external {

        require(msg.sender == deposits[tokenId].owner, "Not the owner");

        positionManager.safeTransferFrom(address(this), msg.sender, tokenId);
        delete deposits[tokenId];
    }

    // function swapExactInputSingle(
    //     address tokenIn,
    //     address tokenOut,
    //     uint24 poolFee,
    //     uint256 amountIn
    // ) external returns (uint256 amountOut) {
    //     IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

    //     IERC20(tokenIn).approve(address(router), amountIn);

    //     ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
    //         .ExactInputSingleParams({
    //             tokenIn: tokenIn,
    //             tokenOut: tokenOut,
    //             fee: poolFee,
    //             recipient: msg.sender,
    //             deadline: block.timestamp,
    //             amountIn: amountIn,
    //             amountOutMinimum: 0,
    //             sqrtPriceLimitX96: 0
    //         });

    //     amountOut = router.exactInputSingle(params);
    // }
}
