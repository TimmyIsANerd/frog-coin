pragma solidity ^0.8.0;

interface IStakingPool {
  event Stake(address account, uint256 amount, uint256 timestamp);
  event Unstake(address account, uint256 amount);
  event Withdrawal(address account, uint256 amount);
  event TaxPercentageChanged(uint8 newTaxPercentage);

  function blockedAddresses(address) external view returns (bool);

  function stakingPoolTax() external view returns (uint8);

  function tokenA() external view returns (address);

  function rewardToken() external view returns (address);

  function stakeERC20(uint256) external;

  function stakeEther() external payable;

  function withdrawRewards() external;

  function apy() external view returns (uint16);

  function withdrawalIntervals() external view returns (uint256);

  function unstakeAmount(uint256) external;

  function unstakeAll() external;

  function taxRecipient() external view returns (address);

  function amountStaked(address) external view returns (uint256);

  function lastStakeTime(address) external view returns (uint256);

  function nextWithdrawalTime(address) external view returns (uint256);
}
