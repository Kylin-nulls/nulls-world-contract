// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../interfaces-external/INullsInvite.sol";
import "../../interfaces/INullsAfterBuyEgg.sol";
import "../../interfaces-external/INullsPromotion.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../interfaces/INullsWorldToken.sol";

contract NullsPromotion is INullsPromotion, Ownable, INullsAfterBuyEgg {

    address RewardToken ;
    uint RewardTotal ;
    uint RewardUsed ;       

    uint RewardStartTime ;
    uint RewardEndTime ;

    mapping(uint8 => uint ) public override RewardValue; 

    mapping(address => uint) public override UserRewards;

    INullsInvite InviteContract;

    address EggContractAddr;

    modifier onlyEggContract() {
        require(EggContractAddr == _msgSender() , "Ownable: caller is not the egg contract");
        _;
    }

    modifier updateStatistics( address user , uint total ) {
        InviteContract.doAfter(user, total );
        _ ;
    }

    function setReward( address token , uint total , uint startTime , uint endTime ) external override onlyOwner {
        RewardToken = token ;
        RewardTotal = total ;
        RewardStartTime = startTime ;
        RewardEndTime = endTime ;
    }

    function setBaseInfo( address inviteAddr , address eggAddr ) external override onlyOwner {
        InviteContract = INullsInvite( inviteAddr ) ;
        EggContractAddr = eggAddr ; 
    }

    function setRewardValue( uint self , uint one , uint two , uint three ) external override onlyOwner {
        RewardValue[0] = self ;
        RewardValue[1] = one ;
        RewardValue[2] = two ;
        RewardValue[3] = three ; 
    }

    function doReward(address buyer, address current , uint total , uint8 index ) internal {
        if( current == address(0) || index >=4 ){
            return ;
        }
        uint balance = RewardTotal - RewardUsed;
        if(balance > 0) {
            (,,,address superior,bool isPartner) = InviteContract.getInviteStatistics( current );
            if (index == 0 || index == 1 || isPartner) {
                uint rewardValue = RewardValue[index] * total ;
                if( rewardValue > balance ) {
                    rewardValue = balance ;
                }
                // IERC20(RewardToken).transfer( current , rewardValue );
                UserRewards[current] += rewardValue;
                RewardUsed += rewardValue ; 
                emit RewardRecord(buyer, current, rewardValue, index,RewardToken, INullsWorldToken(RewardToken).decimals());
            }
            
            index++ ;
            doReward(buyer, superior, total, index);
        }
    }

    function receiveReward() external override {
        uint total = UserRewards[msg.sender];
        uint balance = IERC20(RewardToken).balanceOf( address(this) ) ;
        if (total > 0 && balance > 0) {
            if (total > balance) {
                total = balance;
            }
            IERC20(RewardToken).transfer( msg.sender , total);
            UserRewards[msg.sender] = 0;
            emit ReceiveReward(msg.sender, total);
        }
    }

    function doAfter(address buyer, uint total , address , uint ) external override 
        updateStatistics( buyer , total ) onlyEggContract {

        if( block.timestamp < RewardStartTime ||  block.timestamp > RewardEndTime ) {
            return ;
        }

        doReward(buyer,  buyer , total, 0 );
    }
}