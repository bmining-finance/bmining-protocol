pragma solidity >=0.5.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import './interfaces/IERC20Detail.sol';
import './interfaces/ISwapPair.sol';
import './modules/Ownable.sol';


contract Query is Ownable {

    function getSwapPairReserve(address _pair) public view returns (address token0, address token1, uint8 decimals0, uint8 decimals1, uint reserve0, uint reserve1, uint totalSupply) {
        totalSupply = ISwapPair(_pair).totalSupply();
        token0 = ISwapPair(_pair).token0();
        token1 = ISwapPair(_pair).token1();
        decimals0 = IERC20Detail(token0).decimals();
        decimals1 = IERC20Detail(token1).decimals();
        (reserve0, reserve1, ) = ISwapPair(_pair).getReserves();
    }

}