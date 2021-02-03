pragma solidity >=0.5.0;

interface IMineParam {
    function minePrice() external view returns (uint256);
    function getMinePrice() external view returns (uint256);
    function mineIncomePerTPerSecInWei() external view returns(uint256);
    function incomePerTPerSecInWei() external view returns(uint256);
    function setIncomePerTPerSecInWeiAndUpdateMinePrice(uint256 _incomePerTPerSecInWei) external;
    function updateMinePrice() external;
    function paramSetter() external view returns(address);
    function addListener(address _listener) external;
    function removeListener(address _listener) external returns(bool);
}