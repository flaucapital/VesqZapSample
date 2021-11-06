//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract VesqZap {

    IUniswapV2Router02 private uniswapRouter;
    address public frax;
    
    constructor() {
        uniswapRouter = IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506); //Sushiswap
        frax = 0x45c32fA6DF82ead1e2EF74d17b76547EDdFaFF89;
    }
    
    receive() payable external {} //Important to be able to receive refunded ETH from swapETHForExactTokens

    /** 
     * tokenInAddress: Address of the token that is used for the zaps. Use the 0 address in the case of ETH.
     * amountOutFrax: Exact amounts of FRAX to be swapped for.
     * amountInMax: Maximum amount of token (tokenInAddress) to be used for the swap. Value doesn't matter if zapping ETH as we'll use msg.value.
     * path: The swap path. For ETH, the first address should be the WETH address, not the 0 address.
     */
    function zapToFrax(address tokenInAddress, uint256 amountOutFrax, uint256 amountInMax, address[] calldata path) payable external {
      require((tokenInAddress != address(0) && msg.value == 0) ||  (tokenInAddress == address(0) && msg.value > 0), "ETH only accepted if zapping ETH.");
      require(path[path.length - 1] == frax, "Output of swap must be FRAX.");

      uint256 _amountInMax;
      uint256[] memory _amountPaid; //We're interested only in index 0 - The amount of input token/ETH used.

      if (tokenInAddress != address(0)) {
        _amountInMax = amountInMax;
        TransferHelper.safeTransferFrom(tokenInAddress, msg.sender, address(this), _amountInMax);
        TransferHelper.safeApprove(tokenInAddress, address(uniswapRouter), _amountInMax);
        _amountPaid = uniswapRouter.swapTokensForExactTokens(amountOutFrax, _amountInMax, path, address(this), block.timestamp);
      } else {
        _amountInMax = msg.value;
        _amountPaid = uniswapRouter.swapETHForExactTokens{ value: msg.value }(amountOutFrax, path, address(this), block.timestamp);
      }

      //TODO: Additional code here to use the FRAX we've received from the above swaps to bond, etc.

      //Refund excess token/ETH
      if (_amountPaid[0] < _amountInMax) {
          uint256 _leftoverAmount = _amountInMax - _amountPaid[0];

          if (tokenInAddress != address(0)) {
            TransferHelper.safeTransfer(tokenInAddress, msg.sender, _leftoverAmount);
          }
          else {
            (bool success,) = msg.sender.call{ value: _leftoverAmount }("");
            require(success, "Refund of excess ETH failed");
          }
      }
    }
}