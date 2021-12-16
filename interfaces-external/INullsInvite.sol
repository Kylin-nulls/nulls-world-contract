// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface INullsInvite {

    event Invite(address beInviter, address superior );
    event NewPartner(address player);
    event DelPartner(address player);

  
    function setPartnerCondition(
        uint32 buyEggNumber, 
        uint32 inviteNumber
    ) external;


    function addPartner(
        address user
    ) external;


    function delPartner(
        address user
    ) external;


    function setPromotionContract(
        address contractAddr
    ) external;




    function UserSuperior(
        address user
    ) external view returns(address superior);


    function BuyEggCount(
        address user
    ) external view returns(uint count);

    function ValidInviteCount(
        address user
    ) external view returns(uint count);

    function Partner(
        address user
    ) external view returns(bool isPartner);
    // ---


    function invite(address inviter) external;

  
    function getInviteStatistics(
        address addr
    ) external view returns ( uint32 one , uint32 two , uint32 three , address superior , bool isPartner );

 
    function doAfter(address user, uint count) external;
}