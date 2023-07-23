pragma solidity ^0.8.0;








contract StakingPoolActions is Ownable, AccessControl {
  using Address for address;
  uint256 public deploymentFee;

  bytes32 public feeTakerRole = keccak256(abi.encodePacked("FEE_TAKER_ROLE"));
  bytes32 public feeSetterRole = keccak256(abi.encodePacked("FEE_SETTER_ROLE"));
  bytes32 public excludedFromFeeRole = keccak256(abi.encodePacked("EXCLUDED_FROM_FEE_ROLE"));

  event StakingPoolDeployed(address poolId, address owner, address token0, address token1, uint256 apy, uint8 tax, uint256 endsIn);

  constructor(uint256 _deploymentFee) {
    deploymentFee = _deploymentFee;
    _grantRole(feeTakerRole, _msgSender());
    _grantRole(feeSetterRole, _msgSender());
    _grantRole(excludedFromFeeRole, _msgSender());
  }

  function deployStakingPool(
    address token0,
    address token1,
    uint16 apy,
    uint8 taxPercentage,
    address taxRecipient,
    uint256 withdrawalIntervals,
    uint256 initialAmount,
    int256 daysToLast
  ) external payable returns (address poolId) {
    if (token1 == address(0)) {
      uint256 a;
      if (!hasRole(excludedFromFeeRole, _msgSender())) {
        a = initialAmount + deploymentFee;
      } else a = initialAmount;

      require(msg.value >= a, "fee or amount for ether reward");
    } else {
      if (!hasRole(excludedFromFeeRole, _msgSender())) require(msg.value >= deploymentFee, "fee");
    }

    uint256 endsIn = block.timestamp + (uint256(daysToLast) * 1 days);
    bytes memory bytecode = abi.encodePacked(
      type(StakingPool).creationCode,
      abi.encode(_msgSender(), token0, token1, apy, taxPercentage, taxRecipient, withdrawalIntervals, endsIn)
    );
    bytes32 salt = keccak256(abi.encodePacked(token0, token1, apy, _msgSender(), block.timestamp));

    assembly {
      poolId := create2(0, add(bytecode, 32), mload(bytecode), salt)
      if iszero(extcodesize(poolId)) {
        revert(0, 0)
      }
    }
    if (token1 != address(0) && token1.isContract()) {
      require(IERC20(token1).allowance(_msgSender(), address(this)) >= initialAmount, "not enough allowance");
      TransferHelpers._safeTransferFromERC20(token1, _msgSender(), poolId, initialAmount);
    } else {
      TransferHelpers._safeTransferEther(poolId, initialAmount);
    }

    emit StakingPoolDeployed(poolId, _msgSender(), token0, token1, apy, taxPercentage, endsIn);
  }

  function withdrawEther(address to) external {
    require(hasRole(feeTakerRole, _msgSender()));
    TransferHelpers._safeTransferEther(to, address(this).balance);
  }

  function withdrawToken(
    address token,
    address to,
    uint256 amount
  ) external {
    require(hasRole(feeTakerRole, _msgSender()));
    TransferHelpers._safeTransferERC20(token, to, amount);
  }

  function setFee(uint256 _fee) external {
    require(hasRole(feeSetterRole, _msgSender()));
    deploymentFee = _fee;
  }

  function setFeeSetter(address account) external onlyOwner {
    require(!hasRole(feeSetterRole, account));
    _grantRole(feeSetterRole, account);
  }

  function removeFeeSetter(address account) external onlyOwner {
    require(hasRole(feeSetterRole, account));
    _revokeRole(feeSetterRole, account);
  }

  function setFeeTaker(address account) external onlyOwner {
    require(!hasRole(feeTakerRole, account));
    _grantRole(feeTakerRole, account);
  }

  function removeFeeTaker(address account) external onlyOwner {
    require(hasRole(feeTakerRole, account));
    _revokeRole(feeTakerRole, account);
  }

  function excludeFromFee(address account) external onlyOwner {
    require(!hasRole(excludedFromFeeRole, account));
    _grantRole(excludedFromFeeRole, account);
  }

  function includeInFee(address account) external onlyOwner {
    require(hasRole(excludedFromFeeRole, account));
    _revokeRole(excludedFromFeeRole, account);
  }

  receive() external payable {}
}



