// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../../interfaces/INullsBigPrizePool.sol";

contract NullsBigPrizePool is INullsBigPrizePool, Ownable {
    address public override TokenAddr;

    uint256 public override BeginTime;

    uint256 public override DayIndex;

    uint256 public override PoolTokenAmount;

    uint8 public override TotalPercent;

    mapping(uint256 => uint256) public override DayTokenAmount;

    mapping(address => uint8) public override UserCurrentTransferPercent;

    mapping(address => mapping(uint256 => uint8)) public UserDayTransferPercent;
    mapping(address => uint256[]) public UserTransferPercentModifyHistory;

    mapping(uint256 => uint8) public DayTotalPercent;
    uint256[] public TotalPercentModifyHistory;

    mapping(address => mapping(uint256 => bool)) public TransferOutRecord;

    mapping(address => uint) public override RewardStartDayIndex;

    uint256 public Balance;
    constructor(uint256 ts) {
        if (ts == 0) {
            ts = block.timestamp;
        }
        BeginTime = ts;
    }

    function setTokenAddr(address addr) external override onlyOwner {
        TokenAddr = addr;
    }

    function setTransferPercent(address addr, uint8 percent)
        external
        override
        onlyOwner
    {
        uint256 currentDayIndex = _getDayIndex();

        uint dayIndex = RewardStartDayIndex[addr];

        uint8 oldPercent = UserCurrentTransferPercent[addr];

        if (dayIndex == 0) {
            RewardStartDayIndex[addr] = currentDayIndex + 1;
        }

        TotalPercent = TotalPercent - oldPercent + percent;
        require(
            TotalPercent <= 100,
            "NullsBigPrizePool/The total percentage cannot be greater than 100"
        );

        UserCurrentTransferPercent[addr] = percent;

        uint256[] storage history = UserTransferPercentModifyHistory[addr];

        if (
            history.length == 0 ||
            history[history.length - 1] != currentDayIndex
        ) {
            history.push(currentDayIndex);
        }
        UserDayTransferPercent[addr][currentDayIndex] = percent;

        if (
            TotalPercentModifyHistory.length == 0 ||
            TotalPercentModifyHistory[TotalPercentModifyHistory.length - 1] !=
            currentDayIndex
        ) {
            TotalPercentModifyHistory.push(currentDayIndex);
        }
        DayTotalPercent[currentDayIndex] = TotalPercent;
    }

    function _getDayIndex() internal view returns (uint256 idx) {
        idx = (block.timestamp - BeginTime) / (1 days);
    }

    function _getIndexInTrack(uint256[] memory track, uint256 currentIndex)
        internal
        pure
        returns (bool isSuccess, uint256 index)
    {
        isSuccess = false;
        index = 0;
        for (uint256 i = 0; i < track.length; i++) {
            if (
                track[i] <= currentIndex &&
                (i == track.length - 1 || track[i + 1] > currentIndex)
            ) {
                isSuccess = true;
                index = track[i];
            }
        }
    }

    function _getUserDayTransferPercent(address user, uint256 dayIndex)
        internal
        view
        returns (uint8 percent)
    {
        (bool isSuccess, uint256 index) = _getIndexInTrack(
            UserTransferPercentModifyHistory[user],
            dayIndex
        );
        if (isSuccess) {
            percent = UserDayTransferPercent[msg.sender][index];
        } else {
            percent = 0;
        }
    }

    function getUserDayTransferPercent(address user, uint256 dayIndex)
        external
        view
        override
        returns (uint8 percent)
    {
        percent = _getUserDayTransferPercent(user, dayIndex);
    }

    function _getDayTotalPercent(
        uint256[] memory totalPercentModifyHistory,
        uint256 dayIndex
    ) internal view returns (uint8 percent) {
        (bool isSuccess, uint256 index) = _getIndexInTrack(
            totalPercentModifyHistory,
            dayIndex
        );
        if (isSuccess) {
            percent = DayTotalPercent[index];
        } else {
            percent = 0;
        }
    }

    function getDayTotalPercent(uint256 dayIndex)
        external
        view
        override
        returns (uint8 percent)
    {
        percent = _getDayTotalPercent(TotalPercentModifyHistory, dayIndex);
    }

    function _updateStatistics(uint256 amount) internal {
        uint256 currentDayIndex = _getDayIndex();
        uint256 tmpPoolTokenAmount = PoolTokenAmount;
        bool tmpPoolTokenAmountIsModify = false;

        if (DayIndex != currentDayIndex) {
            uint256[] memory history = TotalPercentModifyHistory;
            for (uint256 i = DayIndex; i < currentDayIndex; i++) {
                uint8 percent = _getDayTotalPercent(history, i);
                if (percent > 0) {
                    tmpPoolTokenAmount -= (tmpPoolTokenAmount * percent) / 100;
                    tmpPoolTokenAmountIsModify = true;
                }
                DayTokenAmount[i] = tmpPoolTokenAmount;
            }
            DayIndex = currentDayIndex;
        }

        if (amount != 0) {
            tmpPoolTokenAmount += amount;
            tmpPoolTokenAmountIsModify = true;
        }

        if (tmpPoolTokenAmountIsModify) {
            PoolTokenAmount = tmpPoolTokenAmount;
        }
    }

    function transferIn() external override {
        uint256 newBalance = IERC20(TokenAddr).balanceOf(address(this));
        _updateStatistics(newBalance - Balance);
        Balance = newBalance;
    }

    function updateStatistics() external {
        _updateStatistics(0);
    }

    function transferOut(uint256 dayIndex)
        external
        override
        returns (uint256 actualAmount)
    {
        require(dayIndex < _getDayIndex(), "NullsBigPrizePool/Must be receive by next day.");
        
        require(TransferOutRecord[msg.sender][dayIndex] == false, "NullsBigPrizePool/Do not receive repeatedly.");

        uint8 percent = _getUserDayTransferPercent(msg.sender, dayIndex);
        if (percent == 0) {
            return 0;
        }

        uint256 dayTokenAmount = DayTokenAmount[dayIndex];
        if (dayTokenAmount == 0) {
            _updateStatistics(0);
            dayTokenAmount = DayTokenAmount[dayIndex];
            if (dayTokenAmount == 0) {
                return 0;
            }
        }
        uint256 amount = (dayTokenAmount * percent) / 100;
        IERC20(TokenAddr).transfer(msg.sender, amount);
        Balance -= amount;
        TransferOutRecord[msg.sender][dayIndex] = true;
        emit RewardReceived(msg.sender, amount, dayIndex, TokenAddr);
        return amount;
    }
}
