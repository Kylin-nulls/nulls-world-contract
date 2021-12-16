// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface INullsEggManager {
    
    event NewPet(
        uint petid, 
        uint batchIndex, 
        uint item, 
        address player, 
        bytes32 v, 
        bytes32 rv,
        bytes32 requestKey
    );

    event EggNewNonce(
        address user,
        uint total,
        uint itemId, 
        bytes32 hv, 
        bytes32 requestKey, 
        uint256 deadline
    );

    event NewEggItem(
        uint itemId,
        address pubkey
    );

    event BuyEgg(
        address user,
        uint number,
        uint payAmount,
        address token
    );

    event RefundEgg(
        address user,
        bytes32 requestKey,
        uint amount
    );


    function setProxy(address proxy) external;

 
 
    function setTransferProxy(address proxy) external;

  
  
    function setPetTokenAndEggToken(address eggToken, address petToken) external;

 
 
    function setAfterProccess(address afterAddr) external;

  
  
    function setBuyToken(address token, uint amount) external;

    function setBigPrizePool(address addr) external;

    function setGodPetProbabilityValue(uint16 val) external;

    function getGodPetProbabilityValue() external view returns(uint16 val);



    function getSceneId() external view returns(uint sceneId);

 
 
    function getPrice(
        address token
    ) external view returns(uint price);

  
  
    function buy(uint total, address token) external;



    function openMultiple(
        uint total, 
        uint itemId, 
        uint256 deadline
    ) external;

    function registerItem(
        address pubkey
    ) external;
}