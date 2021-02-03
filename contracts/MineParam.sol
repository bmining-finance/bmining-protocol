pragma solidity >=0.5.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import './interfaces/IPOWToken.sol';
import "./uniswapv2/UniswapV2OracleLibrary.sol";
import './modules/Paramable.sol';

contract MineParam is Paramable {
    using SafeMath for uint256;

    bool internal initialized;

    uint256 public incomePerTPerSecInWei;

    address public uniPairAddress;
    address public mineAddress;

    uint32 public lastPriceUpdateTime;
    uint256 public lastCumulativePrice;
    uint256 public lastAveragePrice;

    address[] public paramListeners;

    function initialize(uint256 _incomePerTPerSecInWei, address _uniPairAddress, address _mineAddress, address _paramSetter) public {
        require(!initialized, "already initialized");
        initialized = true;
        incomePerTPerSecInWei = _incomePerTPerSecInWei;

        uniPairAddress = _uniPairAddress;
        mineAddress = _mineAddress;
        paramSetter = _paramSetter;
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 currentBlockTimestamp) =
        UniswapV2OracleLibrary.currentCumulativePrices(_uniPairAddress);

        lastPriceUpdateTime = currentBlockTimestamp;
        lastCumulativePrice = IUniswapV2Pair(uniPairAddress).token0()==mineAddress?price0Cumulative:price1Cumulative;
    }

    function updateMinePrice() external onlyParamSetter {
        _updateMinePrice();
        notifyListeners();
    }

    function getMinePrice() public view returns (uint256) {
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 currentBlockTimestamp) =
        UniswapV2OracleLibrary.currentCumulativePrices(uniPairAddress);
        (address token0, , uint8 decimals0, uint8 decimals1) = getPairInfo(uniPairAddress);
        uint256 mineDecimals = uint256(decimals0);
        uint256 baseDecimals = uint256(decimals1);
        uint256 currentPrice = price0Cumulative;
        if(token0 != mineAddress) {
            currentPrice = price1Cumulative;
            mineDecimals = uint256(decimals1);
            baseDecimals = uint256(decimals0);
        }
        

        uint256 timeElapsed = currentBlockTimestamp - lastPriceUpdateTime; // overflow is desired
        uint256 _lastAveragePrice = lastAveragePrice;
        if (timeElapsed > 0) {
            _lastAveragePrice = currentPrice.sub(lastCumulativePrice).div(timeElapsed);
        }
        if (mineDecimals > baseDecimals) {
            return _lastAveragePrice.mul(10**(mineDecimals-baseDecimals)).div(2**112);
        } else if (mineDecimals < baseDecimals) {
            return _lastAveragePrice.div(10**(baseDecimals-mineDecimals)).div(2**112);
        } else {
            return lastAveragePrice.div(2**112);
        }
    }

    function _updateMinePrice() internal {
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 currentBlockTimestamp) =
        UniswapV2OracleLibrary.currentCumulativePrices(uniPairAddress);
        uint256 currentPrice = IUniswapV2Pair(uniPairAddress).token0()==mineAddress?price0Cumulative:price1Cumulative;

        uint256 timeElapsed = currentBlockTimestamp - lastPriceUpdateTime; // overflow is desired
        if (timeElapsed > 0) {
            lastAveragePrice = currentPrice.sub(lastCumulativePrice).div(timeElapsed);
            lastPriceUpdateTime = currentBlockTimestamp;
            lastCumulativePrice = currentPrice;
        }
    }

    function setIncomePerTPerSecInWei(uint256 _incomePerTPerSecInWei) external onlyParamSetter {
        incomePerTPerSecInWei = _incomePerTPerSecInWei;
        notifyListeners();
    }

    function setIncomePerTPerSecInWeiAndUpdateMinePrice(uint256 _incomePerTPerSecInWei) external onlyParamSetter{
        incomePerTPerSecInWei = _incomePerTPerSecInWei;
        _updateMinePrice();
        notifyListeners();
    }

    function addListener(address _listener) external onlyParamSetter {
        for (uint i=0; i<paramListeners.length; i++){
            address listener = paramListeners[i];
            require(listener != _listener, 'listener already added.');
        }
        paramListeners.push(_listener);
    }

    function removeListener(address _listener) external onlyParamSetter returns(bool){
        for (uint i=0; i<paramListeners.length; i++){
            address listener = paramListeners[i];
            if (listener == _listener) {
                delete paramListeners[i];
                return true;
            }
        }
        return false;
    }

    function notifyListeners() internal {
        for (uint i=0; i<paramListeners.length; i++){
            address listener = paramListeners[i];
            if (listener != address(0)) {
                IPOWToken(listener).updateIncomeRate();
            }
        }
    }

    function mineIncomePerTPerSecInWei() external view returns(uint256){
        return incomePerTPerSecInWei;
    }

    function minePrice() external view returns (uint256) {
        if(uniPairAddress == address(0)) {
            return 0;
        }
        (address token0, , uint8 decimals0, uint8 decimals1) = getPairInfo(uniPairAddress);
        uint256 mineDecimals = uint256(decimals0);
        uint256 baseDecimals = uint256(decimals1);
        if(token0 != mineAddress) {
            mineDecimals = uint256(decimals1);
            baseDecimals = uint256(decimals0);
        }
        if (mineDecimals > baseDecimals) {
            return lastAveragePrice.mul(10**(mineDecimals-baseDecimals)).div(2**112);
        } else if (mineDecimals < baseDecimals) {
            return lastAveragePrice.div(10**(baseDecimals-mineDecimals)).div(2**112);
        } else {
            return lastAveragePrice.div(2**112);
        }
    }

    function getPairInfo(address _pair) public view returns (address token0, address token1, uint8 decimals0, uint8 decimals1) {
        token0 = IUniswapV2Pair(_pair).token0();
        token1 = IUniswapV2Pair(_pair).token1();
        decimals0 = IUniswapV2Pair(token0).decimals();
        decimals1 = IUniswapV2Pair(token1).decimals();
    }
}