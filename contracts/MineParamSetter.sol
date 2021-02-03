pragma solidity >=0.5.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import './interfaces/IMineParam.sol';
import './modules/Paramable.sol';

interface IPOWToken {
    function mineParam() external returns (address);
}

contract MineParamSetter is Paramable {
    using SafeMath for uint256;

    uint256 public minIncomeRate;
    uint256 public maxIncomeRate;
    uint256 public minPriceRate;
    uint256 public maxPriceRate;

    function setRate(uint256 _minIncomeRate, uint256 _maxIncomeRate, uint256 _minPriceRate, uint256 _maxPriceRate) public onlyParamSetter {
        minIncomeRate = _minIncomeRate;
        maxIncomeRate = _maxIncomeRate;
        minPriceRate = _minPriceRate;
        maxPriceRate = _maxPriceRate;
    }

    // return >9 is pass
    function checkWithCode (address[] memory params, uint256[] memory values) public view returns (uint256) {
        if(params.length != values.length) {
            return 1;
        }
        for(uint256 i; i<params.length; i++) {
            if(IMineParam(params[i]).paramSetter() != address(this)) {
                return 2;
            }
            uint256 oldIncomePer = IMineParam(params[i]).incomePerTPerSecInWei();
            uint256 oldPrice = IMineParam(params[i]).minePrice();
            uint256 _incomePerTPerSecInWei = values[i];
            
            if(oldIncomePer == 0 || oldPrice == 0) {
                return 10;
            } else {
                uint256 rate;
                if(_incomePerTPerSecInWei > oldIncomePer) {
                    rate = _incomePerTPerSecInWei.sub(oldIncomePer).mul(10000).div(oldIncomePer);
                } else {
                    rate = oldIncomePer.sub(_incomePerTPerSecInWei).mul(10000).div(oldIncomePer);
                }
                if(rate >= minIncomeRate && rate <= maxIncomeRate) {
                    return 11;
                }

                uint256 currentPrice = IMineParam(params[i]).getMinePrice();
                rate = 0;
                if(currentPrice > oldPrice) {
                    rate = currentPrice.sub(oldPrice).mul(10000).div(oldPrice);
                } else {
                    rate = oldPrice.sub(currentPrice).mul(10000).div(oldPrice);
                }
                if(rate >= minIncomeRate && rate <= maxIncomeRate) {
                    return 12;
                }
            }
        }
        return 0;
    }

    function check (address[] memory params, uint256[] memory values) public view returns (bool) {
        uint256 result = checkWithCode(params, values);
        if(result > 9)
            return true;
        return false;
    }

    function update (address[] memory params, uint256[] memory values) public onlyParamSetter {
        require(params.length == values.length, 'invalid parameters');
        for(uint256 i; i<params.length; i++) {
            bool isUpdate;
            uint256 oldIncomePer = IMineParam(params[i]).incomePerTPerSecInWei();
            uint256 oldPrice = IMineParam(params[i]).minePrice();
            uint256 _incomePerTPerSecInWei = values[i];

            if(oldIncomePer == 0 || oldPrice == 0) {
                isUpdate = true;
            } else {
                uint256 rate;
                if(_incomePerTPerSecInWei > oldIncomePer) {
                    rate = _incomePerTPerSecInWei.sub(oldIncomePer).mul(10000).div(oldIncomePer);
                } else {
                    rate = oldIncomePer.sub(_incomePerTPerSecInWei).mul(10000).div(oldIncomePer);
                }
                if(rate >= minIncomeRate && rate <= maxIncomeRate) {
                    isUpdate = true;
                }

                if(!isUpdate) {
                    uint256 currentPrice = IMineParam(params[i]).getMinePrice();
                    if(currentPrice > oldPrice) {
                        rate = currentPrice.sub(oldPrice).mul(10000).div(oldPrice);
                    } else {
                        rate = oldPrice.sub(currentPrice).mul(10000).div(oldPrice);
                    }
                    if(rate >= minIncomeRate && rate <= maxIncomeRate) {
                        isUpdate = true;
                    }
                }
            }
            if(isUpdate) {
                updateOne(params[i], _incomePerTPerSecInWei);
            }
        }
    }

    function updateOne (address param, uint256 _incomePerTPerSecInWei) public onlyParamSetter {
        IMineParam(param).setIncomePerTPerSecInWeiAndUpdateMinePrice(_incomePerTPerSecInWei);
    }

    function updateMinePrice(address param) external onlyParamSetter {
        IMineParam(param).updateMinePrice();
    }

    function addListener(address param, address _listener) external onlyParamSetter {
        IMineParam(param).addListener(_listener);
    }

    function removeListener(address param, address _listener) external onlyParamSetter returns(bool){
        return IMineParam(param).removeListener(_listener);
    }

    function setHashTokenMineParam(address hashToken) public onlyParamSetter {
        IMineParam(IPOWToken(hashToken).mineParam()).addListener(hashToken);
    }

    function setHashTokenMineParams(address[] memory hashTokens) public onlyParamSetter {
        for(uint256 i; i<hashTokens.length; i++) {
            setHashTokenMineParam(hashTokens[i]);
        }
    }
    
}