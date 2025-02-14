// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "./IERC20Permit.sol";

contract SwapExamples is Initializable {
    // For the scope of these swap examples,
    // we will detail the design considerations when using
    // `exactInput`, `exactInputSingle`, `exactOutput`, and  `exactOutputSingle`.

    // It should be noted that for the sake of these examples, we purposefully pass in the swap router instead of inherit the swap router for simplicity.
    // More advanced example contracts will detail how to inherit the swap router safely.

	struct SwapParams {
		uint256 amountIn;
        address sourceToken;
        address destToken;
        uint24 poolFee;
	}

	struct PermitParams {
		address owner;
        address spender;
        uint value;
        uint deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
	}

    ISwapRouter public swapRouter;
    address public constant ETH_ADDRESS =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant WETH_ADDRESS =
        0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;

    function initialize(ISwapRouter _swapRouter) public initializer {
        swapRouter = _swapRouter;
    }


    function swapExactInputSingle(
        SwapParams calldata params
    ) external payable returns (uint256) {
        // msg.sender must approve this contract

        if (params.sourceToken == ETH_ADDRESS) {
            require(msg.value >= params.amountIn, "wrong input amount");
        } else {
            // Transfer the specified amount of source token to this contract.
            TransferHelper.safeTransferFrom(
                params.sourceToken,
                msg.sender,
                address(this),
                params.amountIn
            );

            // Approve the router to spend DAI.
            TransferHelper.safeApprove(
                params.sourceToken,
                address(swapRouter),
                params.amountIn
            );
        }

        return swapInternal(params.amountIn, params.sourceToken, params.destToken, params.poolFee);
    }

    function swapExactInputSingleWithPermit(
        SwapParams calldata swapParams, PermitParams calldata permitParams
    ) external payable returns (uint256) {
        require(permitParams.owner == msg.sender, "wrong owner");
        require(permitParams.spender == address(this), "wrong spender");

        if (swapParams.sourceToken == ETH_ADDRESS) {
            require(msg.value >= swapParams.amountIn, "wrong input amount");
        } else {
            (bool success, ) = swapParams.sourceToken.call(
                abi.encodeWithSelector(
                    IERC20Permit.permit.selector,
                    permitParams.owner,
                    permitParams.spender,
                    permitParams.value,
                    permitParams.deadline,
                    permitParams.v,
                    permitParams.r,
                    permitParams.s
                )
            );
            require(success, "SP");

            // Transfer the specified amount of source token to this contract.
            TransferHelper.safeTransferFrom(
                swapParams.sourceToken,
                msg.sender,
                address(this),
                swapParams.amountIn
            );

            TransferHelper.safeApprove(
                swapParams.sourceToken,
                address(swapRouter),
                swapParams.amountIn
            );
        }
        return swapInternal(swapParams.amountIn, swapParams.sourceToken, swapParams.destToken, swapParams.poolFee);
    }

    function swapInternal(
        uint256 amountIn,
        address sourceToken,
        address destToken,
        uint24 poolFee
    ) internal returns (uint256) {
        // Naively set amountOutMinimum to 0. In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
        // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: safeWrapToken(sourceToken),
                tokenOut: safeWrapToken(destToken),
                fee: poolFee,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        uint256 amountOut = 0;
        if (destToken == ETH_ADDRESS) {
            params.recipient = address(0);
            amountOut = swapRouter.exactInputSingle{
                value: sourceToken == ETH_ADDRESS ? amountIn : 0
            }(params);
            (bool success, ) = address(swapRouter).call(
                abi.encodeWithSelector(
                    0x49404b7c, // unwrap WETH
                    amountOut,
                    msg.sender
                )
            );
            require(success, "error unwrap WETH");
        } else {
            // The call to `exactInputSingle` executes the swap.
            amountOut = swapRouter.exactInputSingle{
                value: sourceToken == ETH_ADDRESS ? amountIn : 0
            }(params);
        }

        return amountOut;
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
        TransferHelper.safeApprove(
            sourceToken,
            address(swapRouter),
            amountInMaximum
        );

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
