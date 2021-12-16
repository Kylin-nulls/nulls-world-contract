// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../interfaces/IZKRandomCallback.sol";
import "../../interfaces/INullsPetToken.sol";
import "../../interfaces/INullsWorldCore.sol";
import "../../interfaces/ITransferProxy.sol";
import "../../interfaces-external/INullsRankManager.sol";
import "../../interfaces/INullsAfterPk.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NullsRankManager is INullsRankManager, IZKRandomCallback, Ownable {

    struct RankTokenConfig {
        uint minInitialCapital;
        bool isOk ;
    }

    struct DataInfo {
        uint challengerPetId;
        uint itemId;
        address player;
        bool isOk;
    }

    struct PkPayRecord {
        bool isAvailable;
        address token;
        uint amount;
    }

    using Counters for Counters.Counter;

    address PkAfter ;

    address Proxy = address(0);
    address PetToken = address(0);
    ITransferProxy TransferProxy;
    bool IsOk = true;
    uint SceneId ;

    uint GeneralPetRestTime = 300;

    uint public RankDeadline = 600;

    mapping(address => Counters.Counter) Nonces;
 
    mapping( address => RankTokenConfig ) RankTokens;

    mapping( uint => uint) public override LastChallengeTime;

    mapping( uint256 => Rank) Ranks;

    mapping( uint => bool ) PetLocked; // petid -> beating  

    mapping( bytes32 => DataInfo) DataInfos;

    mapping(bytes32 => bytes32) KeyToHv;

    mapping(bytes32 =>  PkPayRecord) PkPayRecords;

    mapping(uint256 => uint256) public RankQueueLen;

    modifier isFromProxy() {
        require(msg.sender == Proxy, "NullsOpenEggV1/Is not from proxy.");
        _;
    }

    function setRestTime( uint generalPetRestTime) external override onlyOwner {
        GeneralPetRestTime = generalPetRestTime;
    }

    function setTransferProxy(address proxy) external override onlyOwner {
        TransferProxy = ITransferProxy(proxy);
    }

    function setAfterProccess( address afterAddr ) external override onlyOwner {
        PkAfter = afterAddr ;
    }

    function getRankInfo(uint256 rankId) external override view returns(Rank memory rank) {
        rank = Ranks[rankId];
    }

    function getRestTime() external view override returns(uint generalPetRestTime) {
        return GeneralPetRestTime;
    }

    function addRankToken( address token, uint minInitialCapital) external override onlyOwner {
        RankTokens[ token ] = RankTokenConfig({
            minInitialCapital: minInitialCapital,
            isOk: true
        }) ;
    }

    function setProxy(address proxy) external override onlyOwner {
        Proxy = proxy;
        SceneId = INullsWorldCore(Proxy).newScene(address(this));
    }

    function getSceneId() external override view returns(uint sceneId) {
        return SceneId;
    }

    function getPrice(address token) external override view returns(uint price) {
        RankTokenConfig memory rankTokenConfig = RankTokens[token];
        require(rankTokenConfig.isOk, "NullsRankManager/Unsupported token");
        price = rankTokenConfig.minInitialCapital;
    }

    function setPetToken( address petToken ) external override onlyOwner {
        PetToken = petToken ;
    }

    function setRankDeadline(uint value) external onlyOwner {
        RankDeadline = value;
    }

    function nonces(address player) external override view returns (uint256) {
        return Nonces[player].current();
    }

    function _useNonces(address player) internal returns (uint256 current) {
        Counters.Counter storage counter = Nonces[player];
        current = counter.current();
        counter.increment();
    }
  
    function encodePack(
        uint petId, 
        address token,
        uint8 multiple,
        uint256 nonce
    ) internal view returns (bytes32 v) {

        bytes32 t = keccak256(
            abi.encode(
                "nulls.online-play",
                petId,
                token,
                multiple,
                nonce,
                block.chainid
            )
        );
        v = keccak256( abi.encodePacked(
            "\x19Ethereum Signed Message:\n32" , t
        )) ;
    }
    
    function createRank(
        uint petId, 
        address token,
        uint8 multiple,
        uint8 rewardRatio
    ) external override returns(uint256 itemId) {

            require(rewardRatio >= 50 && rewardRatio <= 100, "NullsRankManager/The rewardRatio must be between 50 and 100");

            bool isLocked = PetLocked[petId] ;
            require( isLocked == false , "NullsRankManager/The pet is beating.");

            require(RankTokens[token].isOk == true, "NullsRankManager/Unsupported token.");
            require(multiple == 5 || multiple== 10, "NullsRankManager/Unsupported multiple.");

            require(INullsPetToken( PetToken ).ownerOf(petId) == msg.sender, "NullsRankManager/Pet id is illegal");
            require(
                uint8(
                    bytes1(
                        INullsPetToken( PetToken ).Types(petId)
                    )
                ) == 0xff, "NullsRankManager/Pets do not have the ability to open the Rank");
            uint initialCapital = RankTokens[token].minInitialCapital * multiple;
            TransferProxy.erc20TransferFrom(token, msg.sender, address(this), initialCapital);
            itemId = INullsWorldCore(Proxy).newItem( SceneId , address(0), 1);

            Ranks[itemId] = Rank({
                petId: petId,
                token: token,
                initialCapital: initialCapital,
                ticketAmt : RankTokens[token].minInitialCapital ,
                multiple: multiple,
                creater: msg.sender,
                bonusPool: initialCapital,
                ownerBonus: 0,
                gameOperatorBonus: 0,
                total: 0,
                rewardRatio: rewardRatio,
                lastActivityTime: block.timestamp
            });

            PetLocked[petId] = true ;            
            emit NewRank(itemId, petId, token, initialCapital, msg.sender, multiple, address(0), rewardRatio);
    }

    function getRewardRatio(uint total) internal pure returns(uint8 RankPool, uint8 RankOwner, uint8 gameOperator) {
        if (total <= 10) {
            RankPool = 6;
            RankOwner = 3;
            gameOperator = 1;
        } else if (total > 10 && total <= 20) {
            RankPool = 7;
            RankOwner = 2;
            gameOperator = 1;
        } else {
            RankPool = 8;
            RankOwner = 1;
            gameOperator = 1;
        }
    }

    function doReward(address player, uint256 itemId, bytes32 rv, uint challengerPetId, bytes32 requestKey) internal {
        Rank memory rank = Ranks[itemId];

        uint challengeCapital = rank.ticketAmt;
        
        if (rank.bonusPool == 0) {
            PkPayRecord memory pkPayRecord = PkPayRecords[requestKey];
            if (pkPayRecord.token == rank.token && pkPayRecord.amount == challengeCapital) {
                IERC20( rank.token ).transfer( player, pkPayRecord.amount);
                emit RefundPkFee(player, requestKey, pkPayRecord.amount);
            }
            return;
        }


        (uint8 RankPoolRatio, uint8 RankOwnerRatio, uint8 gameOperatorRatio) = getRewardRatio(rank.total);

        rank.bonusPool += challengeCapital * RankPoolRatio / 10;

        rank.ownerBonus += challengeCapital * RankOwnerRatio / 10;

        rank.gameOperatorBonus += challengeCapital * gameOperatorRatio / 10;
        

        if (uint8(bytes1(rv)) % 16 == 0) {
            if (challengeCapital * 10 > rank.bonusPool) {
                
                IERC20( rank.token ).transfer( player, rank.bonusPool);
                address RankOwner = INullsPetToken( PetToken ).ownerOf(rank.petId);
                IERC20( rank.token ).transfer( RankOwner, rank.ownerBonus);
                rank.ownerBonus = 0;

                IERC20( rank.token ).transfer( owner() , rank.gameOperatorBonus); 
                rank.gameOperatorBonus = 0;

                PetLocked[rank.petId] = false ;

                emit RankUpdate(itemId, challengerPetId, LastChallengeTime[challengerPetId], player, 0, rv, true, rank.bonusPool, requestKey, rank.token);
                rank.bonusPool = 0;     
            } else {
                uint rewardValue = rank.bonusPool * rank.rewardRatio / 100;
                IERC20( rank.token ).transfer( player, rewardValue );
                emit RankUpdate(itemId, challengerPetId, LastChallengeTime[challengerPetId], player, rank.bonusPool - rewardValue , rv, true , rewardValue, requestKey, rank.token);
                rank.bonusPool = rank.bonusPool - rewardValue;
            }
        } else {
            emit RankUpdate(itemId, challengerPetId, LastChallengeTime[challengerPetId], player, rank.bonusPool, rv, false , challengeCapital * RankPoolRatio / 10, requestKey, rank.token);
        }
        rank.total += 1;
        Ranks[itemId] = rank;

        if (PkAfter != address(0)) {
            INullsAfterPk(PkAfter).doAfterPk(player, rank.token, challengeCapital);
        }
        
    }

    function pk(
        uint256 itemId,
        uint challengerPetId,
        uint256 deadline
    ) external override {

        require(
                uint8(
                    bytes1(
                        INullsPetToken( PetToken ).Types(challengerPetId)
                    )
                ) != 0xff, "NullsRankManager/Challenge pets cannot participate in pk");

        require(block.timestamp <= deadline, "NullsRankManager: expired deadline");

        require(INullsPetToken( PetToken ).ownerOf(challengerPetId) == msg.sender, "NullsRankManager/Pet id is illegal");

        require(block.timestamp > LastChallengeTime[challengerPetId] , "NullsRankManager/Pets at rest");

        Rank storage rank = Ranks[itemId];

        require(rank.bonusPool > 0, "NullsRankManager/The rank is closed");
        uint challengeCapital = rank.ticketAmt;
        TransferProxy.erc20TransferFrom(rank.token, msg.sender, address(this) , challengeCapital);

        LastChallengeTime[challengerPetId] = block.timestamp + GeneralPetRestTime;

        bytes32 hv = keccak256(
            abi.encode(
                "nulls.egg",
                challengerPetId,
                itemId,
                deadline,
                _useNonces(msg.sender),
                block.chainid
            )
        );
        
        bytes32 requestKey = INullsWorldCore(Proxy).getNonce(itemId, hv);

        PkPayRecords[requestKey] = PkPayRecord({
            isAvailable: true,
            token: rank.token,
            amount: challengeCapital
        });

        KeyToHv[requestKey] = hv; 

        DataInfos[hv] = DataInfo({
            challengerPetId: challengerPetId,
            itemId: itemId,
            player: msg.sender,
            isOk: true
        });

        RankQueueLen[itemId] += 1;
        rank.lastActivityTime = block.timestamp;

        emit RankNewNonce(itemId, challengerPetId, hv, requestKey, deadline, msg.sender);
    }

    function closeRank(uint itemId) external {
        Rank storage rank = Ranks[itemId];

        require(rank.lastActivityTime + RankDeadline < block.timestamp, "NullsRankManager/Closing time is not reached");
        require(rank.bonusPool > 0, "NullsRankManager/Closed");
        require(INullsPetToken( PetToken ).ownerOf(rank.petId) == msg.sender, "NullsRankManager/Pet id is illegal");
        require(rank.total >= 10, "NullsRankManager/Not enough challenges");

        // send to rank owner
        IERC20( rank.token ).transfer( msg.sender, rank.ownerBonus + rank.bonusPool);
        rank.ownerBonus = 0;
        rank.bonusPool = 0;

        IERC20( rank.token ).transfer( owner() , rank.gameOperatorBonus);
        rank.gameOperatorBonus = 0;

        PetLocked[rank.petId] = false ;

        emit RankClosed(itemId, msg.sender, rank.ownerBonus + rank.bonusPool, rank.gameOperatorBonus);

    }

    function refund(bytes32 requestKey) external {
      bytes32 hv = KeyToHv[requestKey]; 
      DataInfo memory info = DataInfos[hv];
      require(msg.sender == info.player && info.isOk, "NullsRankManager/Illegal operation");
      require(!INullsWorldCore(Proxy).checkRequestKey(requestKey), "NullsRankManager/Refund time is not due");
      PkPayRecord storage pkPayRecord = PkPayRecords[requestKey];
      require(pkPayRecord.isAvailable, "NullsRankManager/No refund");
      IERC20(pkPayRecord.token).transfer(msg.sender, pkPayRecord.amount);
      pkPayRecord.isAvailable = false;
      emit RefundPkFee(msg.sender, requestKey, pkPayRecord.amount);
    }

    function withdrawRankAward(uint item) external {
        Rank storage rank = Ranks[item];
        require(rank.bonusPool > 0, "NullsRankManager/The rank is closed");
        require(INullsPetToken( PetToken ).ownerOf(rank.petId) == msg.sender, "NullsRankManager/Pet id is illegal");

        // send to 
        IERC20( rank.token ).transfer( msg.sender, rank.ownerBonus);
        emit RewardToRankOwner(msg.sender, rank.ownerBonus);
        rank.ownerBonus = 0;

        IERC20( rank.token ).transfer( owner() , rank.gameOperatorBonus);
        emit RewardToGameOperator(owner(), rank.gameOperatorBonus);
        rank.gameOperatorBonus = 0;
    }

    function getRestStatus(uint256 petId) view external returns (uint currentBlockTime, uint restEndTime) {
        currentBlockTime = block.timestamp;
        restEndTime = LastChallengeTime[petId];
    }

    // Receive proxy's message 
    function notify( uint item , bytes32 key , bytes32 rv ) external override isFromProxy returns ( bool ) {
        
        bytes32 hv = KeyToHv[key];
        DataInfo memory dataInfo = DataInfos[hv];
        require(item == dataInfo.itemId, "NullsRankManager/Item verification failed");

        require(dataInfo.player != address(0), "NullsRankManager/The data obtained by HV is null");
        require(dataInfo.isOk, "NullsRankManager/Do not repeat consumption.");

        if (PkPayRecords[key].isAvailable) {
          doReward(dataInfo.player, dataInfo.itemId, rv, dataInfo.challengerPetId, key);
        }
        
        dataInfo.isOk = false;
        DataInfos[hv] = dataInfo;
        RankQueueLen[item] -= 1;
        return true;
    }
}