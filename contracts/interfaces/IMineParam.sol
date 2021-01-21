pragma solidity >=0.5.0;

interface IMineParam {
    function minePrice() external view returns (uint256);
    function mineIncomePerTPerSecInWei() external view returns(uint256);
}