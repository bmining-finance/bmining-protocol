pragma solidity >=0.5.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import './interfaces/IPOWToken.sol';
import "./uniswapv2/UniswapV2OracleLibrary.sol";
import './modules/Paramable.sol';

contract BTCParamV2 is Paramable {
    using SafeMath for uint256;

    bool internal initialized;

    uint256 public mineBlockRewardInWei;
    uint256 public mineNetDiff;
    uint256 public mineTxFeeRewardPerTPerSecInWei;
    uint256 public incomePerTPerSecInWei;

    address public uniPairAddress;
    bool public usePrice0;
    uint32 public lastPriceUpdateTime;
    uint256 public lastCumulativePrice;
    uint256 public lastAveragePrice;

    address[] public paramListeners;

    // _usePrice0=true: token0 is wbtc
    function initialize(uint256 _mineNetDiff, uint256 _mineBlockRewardInWei, address _uniPairAddress, bool _usePrice0) public {
        require(!initialized, "already initialized");
        initialized = true;
        mineBlockRewardInWei = _mineBlockRewardInWei;
        mineNetDiff = _mineNetDiff;

        uniPairAddress = _uniPairAddress;
        usePrice0 = _usePrice0;
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 currentBlockTimestamp) =
        UniswapV2OracleLibrary.currentCumulativePrices(_uniPairAddress);

        lastPriceUpdateTime = currentBlockTimestamp;
        lastCumulativePrice = _usePrice0?price0Cumulative:price1Cumulative;
    }


    function setMineNetDiff(uint256 _mineNetDiff) external onlyParamSetter {
        mineNetDiff = _mineNetDiff;
        notifyListeners();
    }

    function setMineBlockReward(uint256 _mineBlockRewardInWei) external onlyParamSetter {
        mineBlockRewardInWei = _mineBlockRewardInWei;
        notifyListeners();
    }

    function updateMinePrice() external onlyParamSetter {
        _updateMinePrice();
        notifyListeners();
    }

    function getMinePrice() public view returns (uint256) {
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 currentBlockTimestamp) =
        UniswapV2OracleLibrary.currentCumulativePrices(uniPairAddress);
        uint256 currentPrice = usePrice0?price0Cumulative:price1Cumulative;

        uint256 timeElapsed = currentBlockTimestamp - lastPriceUpdateTime; // overflow is desired
        uint256 _lastAveragePrice = lastAveragePrice;
        if (timeElapsed > 0) {
            _lastAveragePrice = currentPrice.sub(lastCumulativePrice).div(timeElapsed);
        }
        return _lastAveragePrice.mul(100).div(2**112);
    }

    function _updateMinePrice() internal {
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 currentBlockTimestamp) =
        UniswapV2OracleLibrary.currentCumulativePrices(uniPairAddress);
        uint256 currentPrice = usePrice0?price0Cumulative:price1Cumulative;

        uint256 timeElapsed = currentBlockTimestamp - lastPriceUpdateTime; // overflow is desired
        if (timeElapsed > 0) {
            lastAveragePrice = currentPrice.sub(lastCumulativePrice).div(timeElapsed);
            lastPriceUpdateTime = currentBlockTimestamp;
            lastCumulativePrice = currentPrice;
        }
    }

    function setMineTxFeeRewardRate(uint256 _mineTxFeeRewardPerTPerSecInWei) external onlyParamSetter {
        mineTxFeeRewardPerTPerSecInWei = _mineTxFeeRewardPerTPerSecInWei;
        notifyListeners();
    }

    function setMineTxFeeRewardRateAndUpdateMinePrice(uint256 _mineTxFeeRewardPerTPerSecInWei) external onlyParamSetter{
        mineTxFeeRewardPerTPerSecInWei = _mineTxFeeRewardPerTPerSecInWei;
        _updateMinePrice();
        notifyListeners();
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

    function removeListener(address _listener) external onlyParamSetter returns(bool ){
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
        if(incomePerTPerSecInWei > 0) {
            return incomePerTPerSecInWei;
        }
        uint256 oneTHash = 10 ** 12;
        uint256 baseDiff = 2 ** 32;
        uint256 blockRewardRate = oneTHash.mul(mineBlockRewardInWei).div(baseDiff).div(mineNetDiff);
        return blockRewardRate.add(mineTxFeeRewardPerTPerSecInWei);
    }

    function minePrice() external view returns (uint256) {
        return lastAveragePrice.mul(100).div(2**112);
    }

}