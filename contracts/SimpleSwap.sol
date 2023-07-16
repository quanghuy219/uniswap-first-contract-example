// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.6;
pragma abicoder v2;

import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract SwapExamples {
   // For the scope of these swap examples,
   // we will detail the design considerations when using
   // `exactInput`, `exactInputSingle`, `exactOutput`, and  `exactOutputSingle`.

   // It should be noted that for the sake of these examples, we purposefully pass in the swap router instead of inherit the swap router for simplicity.
   // More advanced example contracts will detail how to inherit the swap router safely.

   ISwapRouter public immutable swapRouter;
   address public constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
   address public constant WETH_ADDRESS = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;

   constructor(ISwapRouter _swapRouter) {
      swapRouter = _swapRouter;
   }

   /// @notice swapExactInputSingle swaps a fixed amount of DAI for a maximum possible amount of WETH9
   /// using the DAI/WETH9 0.3% pool by calling `exactInputSingle` in the swap router.
   /// @dev The calling address must approve this contract to spend at least `amountIn` worth of its DAI for this function to succeed.
   /// @param amountIn The exact amount of DAI that will be swapped for WETH9.
   /// @return amountOut The amount of WETH9 received.
   function swapExactInputSingle(
      uint256 amountIn, address sourceToken, address destToken, uint24 poolFee
   ) external payable returns (uint256 amountOut) {
      // msg.sender must approve this contract

      if (sourceToken == ETH_ADDRESS) {
         require(msg.value >= amountIn, "wrong input amount");
      } else {
         // Transfer the specified amount of source token to this contract.
         TransferHelper.safeTransferFrom(
            sourceToken,
            msg.sender,
            address(this),
            amountIn
         );

         // Approve the router to spend DAI.
         TransferHelper.safeApprove(sourceToken, address(swapRouter), amountIn);
      }

      // Naively set amountOutMinimum to 0. In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
      // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.
      ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
         .ExactInputSingleParams({
               tokenIn: safeWrapToken(sourceToken),
               tokenOut: destToken,
               fee: poolFee,
               recipient: msg.sender,
               deadline: block.timestamp,
               amountIn: amountIn,
               amountOutMinimum: 0,
               sqrtPriceLimitX96: 0
         });

      // The call to `exactInputSingle` executes the swap.
      amountOut = swapRouter.exactInputSingle{value: sourceToken == ETH_ADDRESS ? amountIn : 0}(params);
   }

   /// @notice swapExactOutputSingle swaps a minimum possible amount of DAI for a fixed amount of WETH.
   /// @dev The calling address must approve this contract to spend its DAI for this function to succeed. As the amount of input DAI is variable,
   /// the calling address will need to approve for a slightly higher amount, anticipating some variance.
   /// @param amountOut The exact amount of WETH9 to receive from the swap.
   /// @param amountInMaximum The amount of DAI we are willing to spend to receive the specified amount of WETH9.
   /// @return amountIn The amount of DAI actually spent in the swap.
   function swapExactOutputSingle(
      uint256 amountOut,
      uint256 amountInMaximum,
      address sourceToken,
      address destToken,
      uint24 poolFee
   ) external returns (uint256 amountIn) {
      // Transfer the specified amount of DAI to this contract.
      TransferHelper.safeTransferFrom(
         sourceToken,
         msg.sender,
         address(this),
         amountInMaximum
      );

      // Approve the router to spend the specifed `amountInMaximum` of DAI.
      // In production, you should choose the maximum amount to spend based on oracles or other data sources to acheive a better swap.
      TransferHelper.safeApprove(sourceToken, address(swapRouter), amountInMaximum);

      ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter
         .ExactOutputSingleParams({
               tokenIn: sourceToken,
               tokenOut: destToken,
               fee: poolFee,
               recipient: msg.sender,
               deadline: block.timestamp,
               amountOut: amountOut,
               amountInMaximum: amountInMaximum,
               sqrtPriceLimitX96: 0
         });

      // Executes the swap returning the amountIn needed to spend to receive the desired amountOut.
      amountIn = swapRouter.exactOutputSingle(params);

      // For exact output swaps, the amountInMaximum may not have all been spent.
      // If the actual amount spent (amountIn) is less than the specified maximum amount, we must refund the msg.sender and approve the swapRouter to spend 0.
      if (amountIn < amountInMaximum) {
         TransferHelper.safeApprove(sourceToken, address(swapRouter), 0);
         TransferHelper.safeTransfer(
               sourceToken,
               msg.sender,
               amountInMaximum - amountIn
         );
      }
   }

   function safeWrapToken(address token) internal pure returns (address) {
        return token == ETH_ADDRESS ? WETH_ADDRESS : token;
   }
}
