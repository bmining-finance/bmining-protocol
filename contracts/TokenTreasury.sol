pragma solidity >=0.5.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import "@openzeppelin/contracts/math/SafeMath.sol";
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import "./interfaces/IPOWToken.sol";
import "./interfaces/IERC20Detail.sol";
import "./modules/ReentrancyGuard.sol";
import './modules/Paramable.sol';

contract TokenTreasury is Paramable, ReentrancyGuard{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    mapping (address => bool) public isWhiteListed;

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

    function claim(address _token, uint _amount) external {
        uint256 balance;
        if (_token == address(0)) {
            balance = address(this).balance;
        } else {
            balance = IERC20(_token).balanceOf(address(this));
        }
        require(_amount <= balance, 'TokenTreasury: insufficient balance');
        _transfer(_token,  _amount, msg.sender);
    }

    function transfer(address _token, uint256 _amount, address _to) external onlyOwner {
        _transfer(_token,  _amount, _to);
    }

    function _transfer(address _token, uint256 _amount, address _to) internal {
        require(isWhiteListed[_to], "TokenTreasury: sender is not in whitelist");
        if (_token == address(0)) {
            safeTransferETH(_to, _amount);
        } else {
            IERC20(_token).safeTransfer(_to, _amount);
        }
    }

    function approve(address _token, address _spender, uint256 _amount) public onlyOwner returns (bool) {
        IERC20(_token).approve(_spender, _amount);
        return true;
    }

    function depositeETH() external payable {
        emit DepositedETH(msg.sender, msg.value);
    }

    function safeTransferETH(address to, uint amount) internal {
        address(uint160(to)).transfer(amount);
    }

    event ChangedWhiteList(address indexed _user, bool _old, bool _new);
    event DepositedETH(address indexed _user, uint256 _amount);
}