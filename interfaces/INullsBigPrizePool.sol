// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface INullsBigPrizePool {

    event RewardReceived(
        address addr,
        uint amount,
        uint dayIndex,
        address token
    );

    function TokenAddr() external view returns (address);

    function BeginTime() external view returns (uint256);

    function DayIndex() external view returns (uint256);

    function PoolTokenAmount() external view returns (uint256);

    function TotalPercent() external view returns (uint8);

    function DayTokenAmount(uint256 dayIndex) external view returns (uint256);

    function UserCurrentTransferPercent(address user) external view returns (uint8);

    function RewardStartDayIndex(address contractAddr) external view returns (uint);

    function getUserDayTransferPercent(address user, uint256 dayIndex)
        external
        view
        returns (uint8 percent);

    function getDayTotalPercent(uint256 dayIndex)
        external
        view
        returns (uint8 percent);

    // onlyOwner
    function setTokenAddr(address addr) external;

    // onlyOwner
    function setTransferPercent(address addr, uint8 percent) external;

    // 往奖池里汇款
    function transferIn() external;

    // 从奖池里取款
    function transferOut(uint256 dayIndex)
        external
        returns (uint256 actualAmount);
}
