pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IStakingPool.sol";
import "./helpers/TransferHelper.sol";

contract StakingPool is Ownable, AccessControl, Pausable, ReentrancyGuard, IStakingPool {
  using SafeMath for uint256;
  using Address for address;

  bytes32 public pauserRole = keccak256(abi.encodePacked("PAUSER_ROLE"));

  address public immutable tokenA;
  address public immutable rewardToken;
  address public immutable taxRecipient;

  uint16 public apy;
  uint8 public stakingPoolTax;
  uint256 public withdrawalIntervals;
  uint256 private totalStaked;
  uint256 public endsIn;

  mapping(address => bool) public blockedAddresses;
  mapping(address => uint256) public amountStaked;
  mapping(address => uint256) public lastStakeTime;
  mapping(address => uint256) public nextWithdrawalTime;

  bool private isPoolWiped;

  constructor(
    address newOwner,
    address token0,
    address token1,
    uint16 _apy,
    uint8 poolTax,
    address _taxRecipient,
    uint256 intervals,
    uint256 _endsIn
  ) {
    require(token0 == address(0) || token0.isContract(), "token 0 must be zero address or contract");
    require(token1 == address(0) || token1.isContract(), "token 1 must be zero address or contract");
    tokenA = token0;
    rewardToken = token1;
    apy = _apy;
    stakingPoolTax = poolTax;
    withdrawalIntervals = intervals;

    if (poolTax > 0) {
      require(_taxRecipient != address(0), "tax recipient cannot be zero address if fee is greater than 0");
    }

    taxRecipient = _taxRecipient;
    endsIn = _endsIn;
    _grantRole(pauserRole, _msgSender());
    _grantRole(pauserRole, newOwner);
    _transferOwnership(newOwner);
  }

  function _stake(uint256 amount) private whenNotPaused {
    require(block.timestamp < endsIn, "staking has ended");
    require(!blockedAddresses[_msgSender()], "account has been blocked");
    require(amount > 0, "amount must be greater than 0");

    if (tokenA != address(0)) {
      require(IERC20(tokenA).allowance(_msgSender(), address(this)) >= amount, "not enough allowance is given");
      TransferHelpers._safeTransferFromERC20(tokenA, _msgSender(), address(this), amount);
    }

    uint256 tax = amount.mul(stakingPoolTax) / 100;

    if (tax > 0) {
      if (tokenA == address(0)) TransferHelpers._safeTransferEther(taxRecipient, tax);
      else TransferHelpers._safeTransferERC20(tokenA, taxRecipient, tax);
    }

    amountStaked[_msgSender()] = amountStaked[_msgSender()].add(amount.sub(tax));

    if (lastStakeTime[_msgSender()] == 0) {
      lastStakeTime[_msgSender()] = block.timestamp;
    }

    if (nextWithdrawalTime[_msgSender()] == 0) {
      nextWithdrawalTime[_msgSender()] = block.timestamp.add(withdrawalIntervals);
    }

    totalStaked = totalStaked.add(amount);
  }

  function calculateReward(address account) public view returns (uint256 reward) {
    uint256 percentage = uint256(apy).mul(block.timestamp.sub(lastStakeTime[account]) / (withdrawalIntervals)).div(12);
    reward = amountStaked[account].mul(percentage) / 100;
  }

  function stakeERC20(uint256 amount) external whenNotPaused nonReentrant {
    _stake(amount);
    emit Stake(_msgSender(), amount, block.timestamp);
  }

  function stakeEther() external payable whenNotPaused nonReentrant {
    _stake(msg.value);
    emit Stake(_msgSender(), msg.value, block.timestamp);
  }

  function unstakeAmount(uint256 amount) public nonReentrant {
    require(amount <= amountStaked[_msgSender()], "unstaked amount must be less than or equal to amount staked");

    if (tokenA == address(0)) {
      TransferHelpers._safeTransferEther(_msgSender(), amount);
    } else {
      TransferHelpers._safeTransferERC20(tokenA, _msgSender(), amount);
    }
    amountStaked[_msgSender()] = amountStaked[_msgSender()].sub(amount);

    if (amount == amountStaked[_msgSender()]) {
      delete lastStakeTime[_msgSender()];
      delete nextWithdrawalTime[_msgSender()];
    }
    totalStaked = totalStaked.sub(amount);
    emit Unstake(_msgSender(), amount);
  }

  function unstakeAll() external {
    unstakeAmount(amountStaked[_msgSender()]);
  }

  function withdrawRewards() external whenNotPaused nonReentrant {
    require(block.timestamp < endsIn, "rewards are no longer distributed");
    require(!blockedAddresses[_msgSender()], "account has been blocked");
    require(block.timestamp >= nextWithdrawalTime[_msgSender()], "not time for withdrawal");
    uint256 reward = calculateReward(_msgSender());

    if (rewardToken == address(0)) TransferHelpers._safeTransferEther(_msgSender(), reward);
    else TransferHelpers._safeTransferERC20(rewardToken, _msgSender(), reward);

    lastStakeTime[_msgSender()] = block.timestamp;
    nextWithdrawalTime[_msgSender()] = block.timestamp.add(withdrawalIntervals);
    emit Withdrawal(_msgSender(), reward);
  }

  function retrieveEther(address to) public onlyOwner {
    if (tokenA == address(0)) {
      uint256 amount = address(this).balance.sub(totalStaked);
      TransferHelpers._safeTransferEther(to, amount);
    } else TransferHelpers._safeTransferEther(to, address(this).balance);
  }

  function setStakingPoolTax(uint8 poolTax) external onlyOwner {
    stakingPoolTax = poolTax;
    emit TaxPercentageChanged(poolTax);
  }

  function retrieveERC20(
    address token,
    address to,
    uint256 amount
  ) public onlyOwner {
    require(token.isContract(), "must_be_contract_address");

    if (tokenA == token) {
      uint256 bal = IERC20(token).balanceOf(address(this));
      uint256 a = bal.sub(totalStaked);
      if (a > 0) TransferHelpers._safeTransferERC20(token, to, a);
    } else TransferHelpers._safeTransferERC20(token, to, amount);
  }

  function wipePoolOfRewardTokens(address to) external {
    require(block.timestamp >= endsIn, "staking is still on");
    require(!isPoolWiped, "pool already wiped");
    if (rewardToken == address(0)) retrieveEther(to);
    else {
      uint256 bal = IERC20(rewardToken).balanceOf(address(this));
      retrieveERC20(rewardToken, to, bal);
    }

    isPoolWiped = true;
  }

  function pause() external {
    require(hasRole(pauserRole, _msgSender()));
    _pause();
  }

  function unpause() external {
    require(hasRole(pauserRole, _msgSender()));
    _unpause();
  }

  function switchBlockAddress(address account) external onlyOwner {
    blockedAddresses[account] = !blockedAddresses[account];
  }

  receive() external payable {}
}
