// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface INullsRankManager {


    struct Rank {
        uint petId;
        address token;
        uint ticketAmt ;
        uint initialCapital;
        uint8 multiple;
        address creater;
        uint bonusPool;
        uint ownerBonus;
        uint gameOperatorBonus;
        uint total;
        uint8 rewardRatio;
        uint lastActivityTime;
    }
    
    event NewRank(
        uint256 itemId, 
        uint petId, 
        address token, 
        uint initialCapital, 
        address creater, 
        uint8 multiple, 
        address publicKey,
        uint8 rewardRatio
    );

    event RankUpdate(
        uint256 itemId, 
        uint challengerPetId, 
        uint restEndTime,
        address challenger, 
        uint bonusPool, 
        bytes32 rv, 
        bool isWin, 
        uint value,
        bytes32 requestKey,
        address token
    );

    event RankNewNonce(
        uint itemId, 
        uint challengerPetId,
        bytes32 hv, 
        bytes32 requestKey, 
        uint256 deadline, 
        address user
    );

    event RefundPkFee(
        address user,
        bytes32 requestKey,
        uint amount
    );

    event RewardToRankOwner(
        address user,
        uint amount
    );

    event RewardToGameOperator(
        address user,
        uint amount
    );

    event RankClosed(
        uint itemId,
        address user,
        uint rewardToOwner,
        uint rewardToGameOperator
    );


    function LastChallengeTime(uint petId) external view returns (uint timestamp);
 
    function setRestTime(uint generalPetRestTime) external;

    function setTransferProxy(address proxy) external;

    function setProxy(address proxy) external;


    function setPetToken(address petToken) external;

    function addRankToken(address token, uint minInitialCapital) external;

    function setAfterProccess( address afterAddr ) external;

    function getRankInfo(uint256 rankId) external view returns(Rank memory rank);

    function getRestTime() external view returns(uint generalPetRestTime);

    function getSceneId() external view returns(uint sceneId);

    function getPrice(address token) external view returns(uint price);

    function nonces(address player) external view returns (uint256);

    function createRank(
        uint petId, 
        address token,
        uint8 multiple,
        uint8 rewardRatio
    ) external returns(uint256 itemId);

    function pk(
        uint256 itemId,
        uint challengerPetId,
        uint256 deadline
    ) external;
}