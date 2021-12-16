// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../interfaces-external/INullsInvite.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NullsInvite is Ownable, INullsInvite {
    
 
    mapping(address => mapping(uint32 => uint32)) UserinviteStatistics;

    mapping(address => address) public override UserSuperior;

    mapping(address => uint) public override BuyEggCount;
    mapping(address => uint) public override ValidInviteCount;

    mapping(address => bool ) public override Partner ;

    address PromotionContract;

    uint32 MinBuyEggNumber = 0;
    uint32 MinInviteNumber = 0;

    modifier onlyPromotionContract() {
        require(PromotionContract == _msgSender() , "Ownable: caller is not the promotion contract");
        _;
    }

    function setPartnerCondition(uint32 buyEggNumber, uint32 inviteNumber) external override onlyOwner {
        MinBuyEggNumber = buyEggNumber;
        MinInviteNumber = inviteNumber;
    }

    function addPartner(address user) external override onlyOwner {
        bool isPartner = Partner[user];
        if (isPartner == false) {
            Partner[user] = true;
            emit NewPartner(user);
        }
    }

    function delPartner(address user) external override onlyOwner {
        bool isPartner = Partner[user];
        if (isPartner == true) {
            delete Partner[user];
            emit DelPartner(user);
        }
    }

    function setPromotionContract(address contractAddr) external override onlyOwner {
        PromotionContract = contractAddr;
    }

    function updateInviteStatistics( address current , uint32 index ) internal {
        if( current == address(0) ) {
            return;
        }
        
        if( index > 2 ) {
            return;
        }

        UserinviteStatistics[current][index] = UserinviteStatistics[current][index] + 1  ; 
        address superior = UserSuperior[current] ;
        return updateInviteStatistics( superior , ++index ) ;
    }

    function getInviteStatistics( address addr ) public view override returns ( uint32 one , uint32 two , uint32 three , address superior , bool isPartner ) {
        one = UserinviteStatistics[addr][0] ;
        two = UserinviteStatistics[addr][1] ;
        three = UserinviteStatistics[addr][2] ;
        superior = UserSuperior[addr] ; 
        isPartner = Partner[addr];
    }

    function invite(address inviter ) external override {
        address beInviter = msg.sender ;
        require(inviter != address(0), "NullsInvite/Incorrect account address.");
        require(inviter != beInviter, "NullsInvite/Not allowed to invite myself.");
        require(BuyEggCount[beInviter] == 0, "NullsInvite/The invited user already exists because they have purchased eggs.");
        require(UserSuperior[beInviter] == address(0), "NullsInvite/The invited user already exists because it has been invited by another user");
        (uint32 one,,,,) = getInviteStatistics(beInviter);
        require(one == 0, "NullsInvite/The invited user already exists because he invited other users");

        UserSuperior[beInviter] = inviter;
        updateInviteStatistics( inviter , 0 );
        emit Invite(beInviter, inviter );
    }

    function checkSuperiorBecomePartner(address currentUser) internal {
        if (BuyEggCount[currentUser] == 0) {
            address superior = UserSuperior[currentUser];
            if (superior != address(0)) {
                ValidInviteCount[superior] += 1;
                if (MinInviteNumber == 0) {
                    return;
                }
                ( , , , , bool superiorIsPartner )  = getInviteStatistics(superior);
                if (superiorIsPartner == false) {
                    if ( ValidInviteCount[superior] >= MinInviteNumber ) {
                        Partner[superior] = true;
                        emit NewPartner( superior) ;
                    }
                }
            }
        }
    }

    function checkUserBecomePartner(address currentUser) internal {
        if (MinBuyEggNumber == 0) {
            return;
        }

        bool isPartner = Partner[currentUser];
    
        if( isPartner == false ) {
            if( BuyEggCount[currentUser] >= MinBuyEggNumber ) {
                Partner[currentUser] = true ;
                emit NewPartner( currentUser) ;
            }
        }
    }

    function doAfter(address user, uint count) external override onlyPromotionContract {
        
        if (count == 0) {
            return;
        }

        checkSuperiorBecomePartner(user);
        BuyEggCount[user] += count;
        checkUserBecomePartner(user);

    }
}