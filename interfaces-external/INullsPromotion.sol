// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface INullsPromotion {
    event RewardRecord( address buyer, address target, uint rewardvalue, uint index, address tokenAddr, uint8 decim);
    event ReceiveReward(address user, uint total);

    
    function RewardValue(uint8 grade) external view returns(uint value);

    function UserRewards(address user) external view returns(uint value);

    

    function setReward(
        address token, 
        uint total, 
        uint startTime, 
        uint endTime
    ) external;


    function setBaseInfo(
        address inviteAddr,
        address eggAddr
    ) external;

   
    function setRewardValue( uint self , uint one , uint two , uint three ) external;


    function receiveReward() external;
}