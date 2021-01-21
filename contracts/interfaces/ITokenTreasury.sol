pragma solidity >=0.5.0;

interface ITokenTreasury {
    function claim(address _token, uint _amount) external;
}