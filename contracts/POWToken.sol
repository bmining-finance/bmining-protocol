pragma solidity >=0.5.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import "@openzeppelin/contracts/math/SafeMath.sol";
import './interfaces/IStaking.sol';
import './interfaces/IMineParam.sol';
import './interfaces/ILpStaking.sol';
import './interfaces/ITokenTreasury.sol';
import './modules/POWERC20.sol';
import './modules/Paramable.sol';
import "./interfaces/IERC20Detail.sol";
import './interfaces/ISwapPair.sol';

contract POWToken is Paramable, POWERC20 {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    bool internal initialized;
    address public minter;
    address public stakingPool;
    address public mineParam;
    address public treasury;

    uint256 public elecPowerPerTHSec;
    uint256 public startMiningTime;

    uint256 public electricCharge;
    uint256 public minerPoolFeeNumerator;
    uint256 public depreciationNumerator;
    uint256 public workingRateNumerator;
    uint256 public workingHashRate;
    uint256 public totalHashRate;
    uint256 public workerNumLastUpdateTime;

    address public incomeToken;
    uint256 public incomeRate;
    address public rewardsToken;
    uint256 public rewardRate;
    uint256 public rewardsDuration;
    uint256 public rewardPeriodFinish;
  
    address[] public stakings;
    mapping(address => uint256) public stakingRewardWeight;
    uint256 public stakingRewardWeightTotal;
    mapping(address => uint256) public lpStakingIncomeWeight;
    uint256 public lpStakingIncomeWeightTotal;

    mapping(address => uint256) public stakingType;  // 0: unknown, 1: normal erc20 token, 2: LP token

    function initialize(string memory name, string memory symbol, address _stakingPool, address _lpStakingPool, address _lpStakingPool2, address _minter, address _mineParam, address _incomeToken, address _rewardsToken, address _treasury, uint256 _elecPowerPerTHSec, uint256 _electricCharge, uint256 _minerPoolFeeNumerator, uint256 _totalHashRate) public {
        require(!initialized, "Token already initialized");
        require(_minerPoolFeeNumerator < 1000000, "nonlegal minerPoolFeeNumerator.");

        initialized = true;
        initializeToken(name, symbol);

        stakingPool = _stakingPool; // POWStaking address
        _setStakingPool(stakingPool, 1);
        _setStakingPool(_lpStakingPool, 2);
        _setStakingPool(_lpStakingPool2, 2);

        minter = _minter; // TokenExchange address
        mineParam = _mineParam;
        incomeToken = _incomeToken;
        rewardsToken = _rewardsToken;
        treasury = _treasury;
        elecPowerPerTHSec = _elecPowerPerTHSec;
        startMiningTime =  block.timestamp;
        electricCharge = _electricCharge;
        minerPoolFeeNumerator = _minerPoolFeeNumerator;
        totalHashRate = _totalHashRate;

        rewardsDuration = 30 days;
        depreciationNumerator = 1000000;
        workingHashRate = _totalHashRate;
        workerNumLastUpdateTime = startMiningTime;

        updateIncomeRate();
    }

    function isStakingPool(address _pool) public view  returns (bool) {
        return stakingType[_pool] != 0;
    }

    function setStakingPools(address[] calldata _pools, uint256[] calldata _values) external onlyOwner {
        require(_pools.length == _values.length, 'invalid parameters');
        for(uint256 i; i< _pools.length; i++) {
            _setStakingPool(_pools[i], _values[i]);
        }
        updateStakingPoolsIncome();
        updateStakingPoolsReward();
    }

    function setStakingPool(address _pool, uint256 _value) external onlyOwner {
        _setStakingPool(_pool, _value);
        updateStakingPoolsIncome();
        updateStakingPoolsReward();
    }

    function _setStakingPool(address _pool, uint256 _value) internal {
        if(_pool != address(0)) {
            stakingType[_pool] = _value;
            if(foundStaking(_pool) == false) {
                stakings.push(_pool);
            } 
        }
    }

    function foundStaking(address _pool) public view returns (bool) {
        for(uint256 i; i< stakings.length; i++) {
            if(stakings[i] == _pool) {
                return true;
            }
        }
        return false;
    }

    function countStaking() public view  returns (uint256) {
        return stakings.length;
    }

    function setStakingRewardWeights(address[] calldata _pools, uint256[] calldata _values) external onlyParamSetter {
        require(_pools.length == _values.length, "illegal parameters");
        updateStakingPoolsReward();
        for(uint256 i; i<_pools.length; i++) {
            _setStakingRewardWeight(_pools[i], _values[i]);
        }
    }

    function setStakingRewardWeight(address _pool, uint256 _value) external onlyParamSetter {
        updateStakingPoolsReward();
        _setStakingRewardWeight(_pool, _value);
    }

    function _setStakingRewardWeight(address _pool, uint256 _value) internal {
        require(isStakingPool(_pool), "illegal pool");
        stakingRewardWeightTotal = stakingRewardWeightTotal.sub(stakingRewardWeight[_pool]).add(_value);
        stakingRewardWeight[_pool] = _value;
    }

    function getStakingRewardRate(address _pool) public view returns(uint256) {
        if(stakingRewardWeightTotal == 0) {
            return 0;
        }
        return rewardRate.mul(stakingRewardWeight[_pool]).div(stakingRewardWeightTotal);
    }

    function setLpStakingIncomeWeights(address[] calldata _pools, uint256[] calldata _values) external onlyParamSetter {
        require(_pools.length == _values.length, "illegal parameters");
        updateStakingPoolsIncome();
        for(uint256 i; i<_pools.length; i++) {
            _setLpStakingIncomeWeight(_pools[i], _values[i]);
        }
    }

    function setLpStakingIncomeWeight(address _pool, uint256 _value) external onlyParamSetter {
        updateStakingPoolsIncome();
        _setLpStakingIncomeWeight(_pool, _value);
    }
        
    function _setLpStakingIncomeWeight(address _pool, uint256 _value) internal {
        require(stakingType[_pool] == 2, "illegal pool");
        lpStakingIncomeWeightTotal = lpStakingIncomeWeightTotal.sub(lpStakingIncomeWeight[_pool]).add(_value);
        lpStakingIncomeWeight[_pool] = _value;
    }

    function getLpStakingSupply(address _pool) public view returns(uint256) {
        if(totalSupply == 0 || stakingType[_pool] != 2 || lpStakingIncomeWeightTotal == 0) {
            return 0;
        }

        uint256 poolAmount;
        uint256 windfallAmount;
        {
            uint256 stakingPoolSupply;
            if (stakingPool != address(0)) {
                stakingPoolSupply = IStaking(stakingPool).totalSupply();
            }
            uint256 poolsTotal;
            uint256 unknown;
            (poolAmount, poolsTotal) = getLpStakingsReserve(_pool);
            if(totalSupply > stakingPoolSupply.add(poolsTotal)) {
                unknown = totalSupply.sub(stakingPoolSupply).sub(poolsTotal);
            }
            windfallAmount = unknown.mul(lpStakingIncomeWeight[_pool]).div(lpStakingIncomeWeightTotal);
        }
       
        return poolAmount.add(windfallAmount);
    }

    function getLpStakingsReserve(address _pool) public view returns (uint256, uint256) {
        uint256 total;
        uint256 amount;
        for (uint256 i; i<stakings.length; i++) {
            if(stakingType[stakings[i]] == 2) {
                uint256 _amount = getLpStakingReserve(stakings[i]);
                total = total.add(_amount);
                if(_pool == stakings[i]) {
                    amount = _amount;
                }
            }
        }
        return (amount, total);
    }

    function getLpStakingReserve(address _pool) public view returns (uint256) {
        address pair = ILpStaking(_pool).stakingLpToken();
        if(pair == address(0)) {
            return 0;
        }
        uint256 reserve = getReserveFromLp(pair);
        if(reserve == 0) {
            return 0;
        }
        uint256 stakingAmount = ILpStaking(_pool).totalSupply();
        uint256 pairTotal = ISwapPair(pair).totalSupply();
        if(pairTotal > 0 && reserve.mul(stakingAmount) > pairTotal) {
            return reserve.mul(stakingAmount).div(pairTotal);
        }
        return 0;
    }

    function getReserveFromLp(address _pair) public view returns (uint256) {
        address token0 = ISwapPair(_pair).token0();
        address token1 = ISwapPair(_pair).token1();
        (uint256 reserve0, uint256 reserve1, ) = ISwapPair(_pair).getReserves();
        if (token0 == address(this)) {
            return reserve0;
        } else if (token1 == address(this)) {
            return reserve1;
        }
        return 0;
    }

    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }

    function pause() onlyOwner external {
        _pause();
    }

    function unpause() onlyOwner external {
        _unpause();
    }

    function weiToIncomeTokenValue(uint256 amount) public view returns (uint256) {
        uint256 decimals = 18;
        if(incomeToken != address(0)) {
            decimals = uint256(IERC20Detail(incomeToken).decimals());
        }
        if(decimals < 18) {
            uint diff = 18 - decimals;
            amount = amount.div(10**diff);
        } else if(decimals > 18) {
            uint diff = decimals - 18;
            amount = amount.mul(10**diff);
        }
        return amount;
    }

    function remainingAmount() public view returns(uint256) {
        return totalHashRate.mul(1e18).sub(totalSupply);
    }

    function mint(address to, uint value) external whenNotPaused {
        require(msg.sender == minter, "!minter");
        require(value <= remainingAmount(), "not sufficient supply.");
        _mint(to, value);
        updateStakingPoolsIncome();
    }

    function setMinter(address _minter) external onlyParamSetter {
        require(minter != _minter, "same minter.");
        minter = _minter;
    }

    function addHashRate(uint256 hashRate) external onlyParamSetter {
        require(hashRate > 0, "hashRate cannot be 0");

        // should keep current workingRate and incomeRate unchanged.
        totalHashRate = totalHashRate.add(hashRate.mul(totalHashRate).div(workingHashRate));
        workingHashRate = workingHashRate.add(hashRate);
    }

    function setMineParam(address _mineParam) external onlyParamSetter {
        require(mineParam != _mineParam, "same mineParam.");
        mineParam = _mineParam;
        updateIncomeRate();
    }

    function setStartMiningTime(uint256 _startMiningTime) external onlyParamSetter {
        require(startMiningTime != _startMiningTime, "same startMiningTime.");
        require(startMiningTime > block.timestamp, "already start mining.");
        require(_startMiningTime > block.timestamp, "nonlegal startMiningTime.");
        startMiningTime = _startMiningTime;
        workerNumLastUpdateTime = _startMiningTime;
    }

    function setElectricCharge(uint256 _electricCharge) external onlyParamSetter {
        require(electricCharge != _electricCharge, "same electricCharge.");
        electricCharge = _electricCharge;
        updateIncomeRate();
    }

    function setMinerPoolFeeNumerator(uint256 _minerPoolFeeNumerator) external onlyParamSetter {
        require(minerPoolFeeNumerator != _minerPoolFeeNumerator, "same minerPoolFee.");
        require(_minerPoolFeeNumerator < 1000000, "nonlegal minerPoolFee.");
        minerPoolFeeNumerator = _minerPoolFeeNumerator;
        updateIncomeRate();
    }

    function setDepreciationNumerator(uint256 _depreciationNumerator) external onlyParamSetter {
        require(depreciationNumerator != _depreciationNumerator, "same depreciationNumerator.");
        require(_depreciationNumerator <= 1000000, "nonlegal depreciation.");
        depreciationNumerator = _depreciationNumerator;
        updateIncomeRate();
    }

    function setWorkingHashRate(uint256 _workingHashRate) external onlyParamSetter {
        require(workingHashRate != _workingHashRate, "same workingHashRate.");
        //require(totalHashRate >= _workingHashRate, "param workingHashRate not legal.");

        if (block.timestamp > startMiningTime) {
            workingRateNumerator = getHistoryWorkingRate();
            workerNumLastUpdateTime = block.timestamp;
        }

        workingHashRate = _workingHashRate;
        updateIncomeRate();
    }

    function getHistoryWorkingRate() public view returns (uint256) {
        if (block.timestamp > startMiningTime) {
            uint256 time_interval = block.timestamp.sub(workerNumLastUpdateTime);
            uint256 totalRate = workerNumLastUpdateTime.sub(startMiningTime).mul(workingRateNumerator).add(time_interval.mul(getCurWorkingRate()));
            uint256 totalTime = block.timestamp.sub(startMiningTime);

            return totalRate.div(totalTime);
        }

        return 0;
    }

    function getCurWorkingRate() public view  returns (uint256) {
        return 1000000 * workingHashRate / totalHashRate;
    }

    function getPowerConsumptionMineInWeiPerSec() public view returns(uint256){
        uint256 minePrice = IMineParam(mineParam).minePrice();
        if (minePrice != 0) {
            uint256 Base = 1e18;
            uint256 elecPowerPerTHSecAmplifier = 1000;
            uint256 powerConsumptionPerHour = elecPowerPerTHSec.mul(Base).div(elecPowerPerTHSecAmplifier).div(1000);
            uint256 powerConsumptionMineInWeiPerHour = powerConsumptionPerHour.mul(electricCharge).div(1000000).div(minePrice);
            return powerConsumptionMineInWeiPerHour.div(3600);
        }
        return 0;
    }

    function getIncomeMineInWeiPerSec() public view returns(uint256){
        uint256 paramDenominator = 1000000;
        uint256 afterMinerPoolFee = 0;
        {
            uint256 mineIncomePerTPerSecInWei = IMineParam(mineParam).mineIncomePerTPerSecInWei();
            afterMinerPoolFee = mineIncomePerTPerSecInWei.mul(paramDenominator.sub(minerPoolFeeNumerator)).div(paramDenominator);
        }

        uint256 afterDepreciation = 0;
        {
            afterDepreciation = afterMinerPoolFee.mul(depreciationNumerator).div(paramDenominator);
        }

        return afterDepreciation;
    }

    function updateIncomeRate() public {
        //not start mining yet.
        if (block.timestamp > startMiningTime) {
            // update income first.
            updateStakingPoolsIncome();
        }

        uint256 oldValue = incomeRate;

        //compute electric charge.
        uint256 powerConsumptionMineInWeiPerSec = getPowerConsumptionMineInWeiPerSec();

        //compute mine income
        uint256 incomeMineInWeiPerSec = getIncomeMineInWeiPerSec();

        if (incomeMineInWeiPerSec > powerConsumptionMineInWeiPerSec) {
            uint256 targetRate = incomeMineInWeiPerSec.sub(powerConsumptionMineInWeiPerSec);
            incomeRate = targetRate.mul(workingHashRate).div(totalHashRate);
        }
        //miner close down.
        else {
            incomeRate = 0;
        }

        emit IncomeRateChanged(oldValue, incomeRate);
    }

    function updateStakingPoolsIncome() public {
        for (uint256 i; i<stakings.length; i++) {
            if(msg.sender != stakings[i] && isStakingPool(stakings[i]) && address(this) == IStaking(stakings[i]).hashRateToken()) {
                IStaking(stakings[i]).incomeRateChanged();
            }
        }
    }

    function updateStakingPoolsReward() public {
        for (uint256 i; i<stakings.length; i++) {
            if(msg.sender != stakings[i] && isStakingPool(stakings[i]) && address(this) == IStaking(stakings[i]).hashRateToken()) {
                IStaking(stakings[i]).rewardRateChanged();
            }
        }
    }

    function _setRewardRate(uint256 _rewardRate) internal {
        updateStakingPoolsReward();
        emit RewardRateChanged(rewardRate, _rewardRate);
        rewardRate = _rewardRate;
        rewardPeriodFinish = block.timestamp.add(rewardsDuration);
    }

    function setRewardRate(uint256 _rewardRate)  external onlyParamSetter {
        _setRewardRate(_rewardRate);
    }

    function getRewardRateByReward(uint256 reward) public view returns (uint256) {
        if (block.timestamp >= rewardPeriodFinish) {
            return reward.div(rewardsDuration);
        } else {
            // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
            uint256 remaining = rewardPeriodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardRate);
            return reward.add(leftover).div(rewardsDuration);
        }
    }

    function notifyRewardAmount(uint256 reward) external onlyParamSetter {
        uint _rewardRate = getRewardRateByReward(reward);
        _setRewardRate(_rewardRate);

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        uint balance = IERC20(rewardsToken).balanceOf(address(this));
        require(rewardRate <= balance.div(rewardsDuration), "Provided reward too high");

        emit RewardAdded(reward);
    }

    function takeFromTreasury(address token, uint256 amount) internal {
        if(treasury == address(0)) {
            return;
        }

        uint256 balance;
        if (token == address(0)) {
            balance = address(this).balance;
        } else {
            balance = IERC20(token).balanceOf(address(this));
        }
        if(amount > balance) {
            ITokenTreasury(treasury).claim(token, amount.sub(balance));
        }
    }

    function claimIncome(address to, uint256 amount) external {
        require(to != address(0), "to is the zero address");
        require(isStakingPool(msg.sender), "No permissions");
        
        takeFromTreasury(incomeToken, amount);
        if (incomeToken == address(0)) {
            safeTransferETH(to, amount);
        } else {
            IERC20(incomeToken).safeTransfer(to, amount);
        }

    }

    function claimReward(address to, uint256 amount) external {
        require(to != address(0), "to is the zero address");
        require(isStakingPool(msg.sender), "No permissions");
        
        takeFromTreasury(rewardsToken, amount);
        if (rewardsToken == address(0)) {
            safeTransferETH(to, amount);
        } else {
            IERC20(rewardsToken).safeTransfer(to, amount);
        }
    }

    function inCaseTokensGetStuck(address _token, uint256 _amount) external onlyOwner {
        if (_token == address(0)) {
            safeTransferETH(msg.sender, _amount);
        } else {
            IERC20(_token).safeTransfer(msg.sender, _amount);
        }
    }

    function depositeETH() external payable {
        emit DepositedETH(msg.sender, msg.value);
    }

    function safeTransferETH(address to, uint amount) internal {
        address(uint160(to)).transfer(amount);
    }

    event IncomeRateChanged(uint256 oldValue, uint256 newValue);
    event RewardAdded(uint256 reward);
    event RewardRateChanged(uint256 oldValue, uint256 newValue);
    event DepositedETH(address indexed _user, uint256 _amount);
}