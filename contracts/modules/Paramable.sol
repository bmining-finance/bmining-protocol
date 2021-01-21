pragma solidity >=0.5.0;

import './Ownable.sol';

contract Paramable is Ownable {
    address public paramSetter;

    event ParamSetterChanged(address indexed previousSetter, address indexed newSetter);

    constructor() public {
        paramSetter = msg.sender;
    }

    modifier onlyParamSetter() {
        require(msg.sender == owner || msg.sender == paramSetter, "!paramSetter");
        _;
    }

    function setParamSetter(address _paramSetter) external onlyOwner {
        require(_paramSetter != address(0), "param setter is the zero address");
        emit ParamSetterChanged(paramSetter, _paramSetter);
        paramSetter = _paramSetter;
    }

}
