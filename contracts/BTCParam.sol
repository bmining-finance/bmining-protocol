pragma solidity >=0.5.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import './interfaces/IPOWToken.sol';
import './modules/Paramable.sol';

contract BTCParam is Paramable {
    using SafeMath for uint256;

    uint256 public mineBlockRewardInWei;
    uint256 public mineNetDiff;
    uint256 public minePrice;
    uint256 public mineTxFeeRewardPerTPerSecInWei;
    uint256 public incomePerTPerSecInWei;

    address[] public paramListeners;

    function initialize(uint256 _mineNetDiff, uint256 _mineBlockRewardInWei, uint256 _minePrice) public onlyOwner{
        minePrice = _minePrice;
        mineBlockRewardInWei = _mineBlockRewardInWei;
        mineNetDiff = _mineNetDiff;
    }

    function setMineNetDiff(uint256 _mineNetDiff) external onlyParamSetter {
        mineNetDiff = _mineNetDiff;
        notifyListeners();
    }

    function setMineBlockReward(uint256 _mineBlockRewardInWei) external onlyParamSetter {
        mineBlockRewardInWei = _mineBlockRewardInWei;
        notifyListeners();
    }

    function setMinePrice(uint256 _minePrice) external onlyParamSetter {
        minePrice = _minePrice;
        notifyListeners();
    }

    function getMinePrice() public view returns (uint256) {
        return minePrice;
    }

    function setMineTxFeeRewardRate(uint256 _mineTxFeeRewardPerTPerSecInWei) external onlyParamSetter {
        mineTxFeeRewardPerTPerSecInWei = _mineTxFeeRewardPerTPerSecInWei;
        notifyListeners();
    }

    function setIncomePerTPerSecInWei(uint256 _incomePerTPerSecInWei) external onlyParamSetter {
        incomePerTPerSecInWei = _incomePerTPerSecInWei;
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
        uint256 blockRewardRate;
        if(mineNetDiff > 0) {
            blockRewardRate = oneTHash.mul(mineBlockRewardInWei).div(baseDiff).div(mineNetDiff);
        }
        return blockRewardRate.add(mineTxFeeRewardPerTPerSecInWei);
    }

}