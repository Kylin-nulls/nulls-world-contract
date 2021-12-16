//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract LPStaking is Ownable, ReentrancyGuard {
    using Math for uint256;

    address public StakingToken;

    address public RewardsToken;

    uint256 public TotalSupply;

    uint256 public RewardRate;

    uint256 public PeriodFinish = 0;

    mapping(address => uint256) public BalanceOf;

    mapping(address => uint256) public Rewards;

    mapping(address => uint256) Received;

    event Staked(address indexed account, uint256 amount);

    event Withdrawn(address indexed account, uint256 amount);

    event RewardPaid(address indexed account, uint256 amount);

    // constructor(){

    // }

    function setRewardRate(uint256 rate) external onlyOwner {
        RewardRate = rate / 1 days;
    }

    function setBaseInfo(address stakingToken, address rewardToken) external onlyOwner {
        StakingToken = stakingToken;
        RewardsToken = rewardToken;
    }

    function setPeriodFinish(uint periodFinish) external onlyOwner {
        PeriodFinish = periodFinish;
    }

    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        require(amount > 0, "cannot stake 0");
        TotalSupply += amount;
        BalanceOf[msg.sender] += amount;
        IERC20(StakingToken).transferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
        require(amount > 0, "cannot withdraw 0");
        TotalSupply -= amount;
        BalanceOf[msg.sender] -= amount;
        IERC20(StakingToken).transfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function getReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = Rewards[msg.sender];
        require(reward > 0, "cannot reward 0");
        Rewards[msg.sender] = 0;
        IERC20(RewardsToken).transfer(msg.sender, reward);
        emit RewardPaid(msg.sender, reward);
    }

    function exit() external {
        withdraw(BalanceOf[msg.sender]);
        getReward();
    }

    function lastTimeReward() public view returns (uint256) {
        return Math.min(block.timestamp, PeriodFinish);
    }

    function proportion(address account) public view returns (uint256) {
        if (TotalSupply == 0) {
            return 0;
        }
        return (BalanceOf[account] * 1e18) / TotalSupply;
    }

    modifier updateReward(address account) {
        if (BalanceOf[account] > 0) {
            uint256 rate = (lastTimeReward() - Received[account]) * RewardRate;
            Rewards[account] += (rate * proportion(account)) / 1e18;
        }
        Received[account] = lastTimeReward();
        _;
    }
}
