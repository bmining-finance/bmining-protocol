pragma solidity >=0.5.0;

interface ILpStaking {
    function stakingLpToken() external view returns (address);
    function totalSupply() external view returns(uint256);
}