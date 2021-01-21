pragma solidity >=0.5.0;

interface IStaking {
    function incomeRateChanged() external;
    function rewardRateChanged() external;
    function hashRateToken() external view returns(address);
    function totalSupply() external view returns(uint256);
}