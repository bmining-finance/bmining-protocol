pragma solidity >=0.5.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import "@openzeppelin/contracts/math/SafeMath.sol";
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import "./interfaces/IPOWToken.sol";
import "./interfaces/IERC20Detail.sol";
import "./modules/ReentrancyGuard.sol";
import './modules/Paramable.sol';

contract TokenExchange is Paramable, ReentrancyGuard{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    bool private initialized;
    uint256 public constant exchangeRateAmplifier = 1000;
    address public hashRateToken;
    address[] public exchangeTokens;
    mapping (address => uint256) public exchangeRates;
    mapping (address => bool) public isWhiteListed;

    function initialize(address _hashRateToken) public {
        require(!initialized, "already initialized");
        require(IPOWToken(_hashRateToken).minter() == address(this), 'invalid hashRateToken');
        super.initialize();
        initialized = true;
        hashRateToken = _hashRateToken;
    }

    function setWhiteLists (address[] calldata _users, bool[] calldata _values) external onlyOwner {
        require(_users.length == _values.length, 'invalid parameters');
        for (uint i=0; i<_users.length; i++){
            _setWhiteList(_users[i], _values[i]);
        }
    }

    function setWhiteList (address _user, bool _value) external onlyOwner {
        require(isWhiteListed[_user] != _value, 'no change');
        _setWhiteList(_user, _value);
    }

    function _setWhiteList (address _user, bool _value) internal {
        emit ChangedWhiteList(_user, isWhiteListed[_user], _value);
        isWhiteListed[_user] = _value;
    }

    function countExchangeTokens() public view returns (uint256) {
        return exchangeTokens.length;
    }

    function setExchangeRate(address _exchangeToken, uint256 _exchangeRate) external onlyParamSetter {
        exchangeRates[_exchangeToken] = _exchangeRate;
        bool found = false;
        for(uint256 i; i<exchangeTokens.length; i++) {
            if(exchangeTokens[i] == _exchangeToken) {
                found = true;
                break;
            }
        }
        if(!found) {
            exchangeTokens.push(_exchangeToken);
        }
    }

    function remainingAmount() public view returns(uint256) {
        return IPOWToken(hashRateToken).remainingAmount();
    }

    function needAmount(address exchangeToken, uint256 amount) public view returns (uint256) {
        uint256 hashRateTokenDecimal = IERC20Detail(hashRateToken).decimals();
        uint256 exchangeTokenDecimal = IERC20Detail(exchangeToken).decimals();
        uint256 hashRateTokenAmplifier = 10**hashRateTokenDecimal;
        uint256 exchangeTokenAmplifier = 10**exchangeTokenDecimal;

        return amount.mul(exchangeRates[exchangeToken]).mul(exchangeTokenAmplifier).div(hashRateTokenAmplifier).div(exchangeRateAmplifier);
    }

    function exchange(address exchangeToken, uint256 amount, address to) external nonReentrant {
        require(amount > 0, "Cannot exchange 0");
        require(exchangeRates[exchangeToken] > 0, "exchangeRates is 0");
        require(amount <= remainingAmount(), "not sufficient supply");

        uint256 token_amount = needAmount(exchangeToken, amount);
        IERC20(exchangeToken).safeTransferFrom(msg.sender, address(this), token_amount);
        IPOWToken(hashRateToken).mint(to, amount);

        emit Exchanged(msg.sender, exchangeToken, amount, token_amount);
    }

    function ownerMint(uint256 amount, address to) external onlyOwner {
        IPOWToken(hashRateToken).mint(to, amount);
    }

    function claim(address _token, uint256 _amount) external {
        require(isWhiteListed[msg.sender], "sender is not in whitelist");
        if (_token == address(0)) {
            safeTransferETH(msg.sender, _amount);
        } else {
            IERC20(_token).safeTransfer(msg.sender, _amount);
        }
    }

    function safeTransferETH(address to, uint amount) internal {
        address(uint160(to)).transfer(amount);
    }

    event Exchanged(address indexed user, address indexed token, uint256 amount, uint256 token_amount);
    event ChangedWhiteList(address indexed _user, bool _old, bool _new);
}