//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../../interfaces/INullsBigPrizePool.sol";

contract StakingCore is Ownable, ReentrancyGuard {
    using Math for uint256;

    //stakingAccount
    struct Account {
        uint256 amount;
        uint256 total;
        uint256 start;
        uint256 unlockTime;
        uint256 rate;
    }

    struct Bonus {
        uint256 amount;
        uint256 totalStaking;
    }

    struct Interest {
        uint256 time;
        uint256 rate;
        bool open;
    }

    INullsBigPrizePool public PrizePool;
    address public RewardsToken;
    uint256 public PrizePoolIndex;
    address public StakingToken;

    uint256 public StartTime;

    uint256 public TotalSupply;

    uint256 public TotalRewards;

    mapping(address => uint256) public BalanceOf;

    mapping(address => mapping( uint256 => Account)) public Voucher;

    Interest[] public InterestRecord;

    Bonus[] public BonusRecord;

    event Staked(address indexed account, uint256 amount,uint256 index);
    event Withdraw(address indexed account, uint256 amount,uint256 index);
    event Reward(address indexed account, uint256 amount, uint256 index);
    event NotifyInterest(uint256 index,uint256  time, uint256 rate , bool open);
    event NotifyBonus(uint256 indexed index, uint256 rewards,uint256 totalStaking);
    constructor(
        uint256 _startTime,
        address _stakingToken,
        address _prizePool
    ) {
        StartTime = _startTime;
        StakingToken = _stakingToken;
        PrizePool = INullsBigPrizePool(_prizePool);
        RewardsToken = PrizePool.TokenAddr();
        // current
        Interest memory interst =Interest({
            time: 0,
            rate: 1000,
            open: true
        });
        InterestRecord.push(interst);
        
    }

    modifier onStart() {
        require(block.timestamp > StartTime, "The event has not yet started");
        _;
    }

    function stake(uint256 index, uint256 amount)  external nonReentrant onStart{
        require(amount > 0, "amount cannot 0");
        require(IERC20(StakingToken).transferFrom(msg.sender, address(this), amount), "transfer error");
        Interest memory interst = InterestRecord[index];
        require(interst.open, "Not opened");
        Account memory account= Voucher[msg.sender][index];
        //new account or withdraw all
        if(account.amount == 0){
            account.start = BonusRecord.length == 0 ? 0 : BonusRecord.length + 1;
            account.rate = interst.rate;
        }
        require(account.start >= BonusRecord.length, "You need to collect all rewards first");
        //rate is modify , update account total
        if(interst.rate != account.rate){
           amount += _oldStake(account);
        }
        //total
        uint256 total = (amount * interst.rate) / 1000;

        account.amount += amount;
        account.total += total;
        account.unlockTime = block.timestamp + interst.time;
        account.rate = interst.rate;

        Voucher[msg.sender][index] = account;
        TotalSupply += total;
        BalanceOf[msg.sender] += total;
        emit Staked(msg.sender, amount, index);   
    }

    function _oldStake(Account memory account) internal returns (uint256 amount){
        amount= account.amount;
        TotalSupply -=  account.total;
        BalanceOf[msg.sender] -= account.total;
        account.amount = 0;
        account.total = 0;
    }

    function getReward(uint256 index) external nonReentrant {
       (uint256 amount, uint256 start) = earned(msg.sender,index);
        Account memory account = Voucher[msg.sender][index];
        require(account.amount > 0, "No claimable amount");
        require(start > account.start, "Not available for collection");
        TotalRewards -= amount;
        if(amount > 0){
            require(
            IERC20(RewardsToken).transfer(msg.sender, amount),
            "transfer error"
        );
        }
        account.start = start;
        Voucher[msg.sender][index] = account;
        emit Reward(msg.sender, amount, index);
    }


    function withdraw(uint256 index, uint256 amount) external nonReentrant {
        Account memory account = Voucher[msg.sender][index];
        require(account.amount > 0 && account.amount > amount, "Wrong amount withdrawn");
        require(block.timestamp > account.unlockTime, "Lockout time is not over");
        uint256 total= amount * account.rate / 1000;
        TotalSupply -= total;
        BalanceOf[msg.sender] -= total;
        account.amount -= amount;
        account.total -= total;
        Voucher[msg.sender][index] = account;
        IERC20(StakingToken).transfer(msg.sender, amount);
        emit Withdraw(msg.sender, amount, index);
    }

    function notifyBonus() external onlyOwner {
        if(PrizePoolIndex == 0){
            PrizePoolIndex = PrizePool.RewardStartDayIndex(address(this))-1;
        }
        uint256 index = PrizePoolIndex;
        uint256 len = Math.min(index + 10, PrizePool.DayIndex());
        require(index < len, "No rewards available");
        for (; index < len; index++) {
            uint256 amount = PrizePool.transferOut(index);
            Bonus memory bonus = Bonus({
                amount: amount,
                totalStaking: TotalSupply
            });
            TotalRewards += amount;
            BonusRecord.push(bonus);
            emit NotifyBonus(BonusRecord.length, amount,TotalSupply);
        }
        PrizePoolIndex = index;
    }

    function notifyInterest(uint256 index,uint256 time,uint256 rate, bool open) external nonReentrant onlyOwner{
        Interest memory interst = Interest({
            time: time,
            rate: rate,
            open: open
        });

        uint256 length = InterestRecord.length;
        if(index >= length){
            // push
            InterestRecord.push(interst);
            index = length;
        } else {
            //update
            InterestRecord[index] = interst;
        }
        emit NotifyInterest( index, time, rate, open);
    }

    function interestRecordLength() public view returns(uint256) {
        return InterestRecord.length;
    }


    function bonusRecordLength() public view returns(uint256) {
        return BonusRecord.length;
    }

    function earned(address addr,uint256 index) public view returns(uint256 amount,uint256 start) {
        Account memory account = Voucher[addr][index];

        uint256 len = Math.min(account.start + 20, BonusRecord.length);
        start = account.start;
        amount = 0;
        for (; start < len; start++) {
            Bonus memory rewards = BonusRecord[start];
            uint256 reward = account.total * rewards.amount * 1e18 / rewards.totalStaking;
            if(reward > 1e18){
                amount += reward / 1e18;
            }
        }
    } 

    function test(address rewardsToken,uint256 amount) external onlyOwner{
        RewardsToken = rewardsToken;
        require(IERC20(rewardsToken).transferFrom(msg.sender, address(this), amount), "transfer error");
        Bonus memory bonus = Bonus({
            amount: amount,
            totalStaking: TotalSupply
        });
        TotalRewards += amount;
        BonusRecord.push(bonus);
        emit NotifyBonus(BonusRecord.length, amount,TotalSupply);
    }


}
