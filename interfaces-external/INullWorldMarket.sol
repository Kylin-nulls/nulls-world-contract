//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface INullWorldMarket {

    struct Token {
        bool supported;
        uint256 feeRate;
    }
    struct SellInfo {
        bool isSell;
        address token;
        uint256 price;
        address seller;
        uint256 count;
    }

    event SellPet(
        uint256 petId,
        uint256 count,
        address tokenAddr,
        uint256 price,
        address seller
    );

    event UnSellPet(
        uint256 petId, 
        uint256 count, 
        address seller
    );

    event SuccessSell(
        uint256 petId,
        uint256 amount,
        address seller,
        address buyer
    );

   
    function setTransferProxy(address proxy) external;


    function setSupportedToken(
        address tokenAddr,
        bool supported,
        uint256 feeRate
    ) external;

 
    function getSupportedToken(
        address tokenAddr
    ) external view returns(Token memory tokenInfo);
    
 
    function sellPet(
        uint256 petId,
        address tokenAddr,
        uint256 price
    ) external;


    function getPetSellInfos(
        uint256 petId
    ) external view returns(SellInfo memory sellInfo);


    function unSellPet(uint256 petId) external;

 
    function buyPet(uint256 petId) external;
}