// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../interfaces/IZKRandomCallback.sol";
import "../../interfaces/INullsEggToken.sol";
import "../../interfaces/INullsPetToken.sol";
import "../../interfaces/INullsAfterBuyEgg.sol";
import "../../interfaces/INullsWorldCore.sol";
import "../../interfaces/ITransferProxy.sol";
import "../../interfaces-external/INullsEggManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "../../interfaces/INullsBigPrizePool.sol";

contract NullsEggManager is INullsEggManager, IZKRandomCallback, Ownable {

    struct BuyToken {
        uint amount ;
        bool isOk ;
    }

    struct DataInfo {
        uint total;
        uint itemId;
        address player;
        bool isOk;
    }

    struct OpenEggRecord {
        bool isAvailable;
        uint amount;
    }

    address EggToken ;
    address PetToken ;
    address Proxy;
    address BuyTokenAfter ;
    address BigPrizePool;
    ITransferProxy TransferProxy;
    uint SceneId;

    uint public GodPetCount;

    mapping( address => BuyToken ) BuyTokens ;

    using Counters for Counters.Counter;

    mapping(address => Counters.Counter) Nonces;

    mapping( bytes32 => DataInfo) DataInfos;

    mapping(bytes32 => bytes32) KeyToHv;

    mapping(bytes32 => OpenEggRecord) OpenEggRecords;

    address BuyAfterAddress ;   

    bool IsOk = true;

    uint16 GodPetProbabilityValue = 0;

    mapping(address => uint16) public GodPetProbability;

    mapping(address => bool) WhiteList;

    function addWhiteList(address user) external onlyOwner {
        WhiteList[user] = true;
    }
 
    modifier onlyOwnerOrWhiteList() {
        require(owner() == _msgSender() || WhiteList[_msgSender()] == true, "Ownable: caller is not the owner or white list");
        _;
    }

    modifier isFromProxy() {
        require(msg.sender == Proxy, "NullsEggManager/Is not from proxy.");
        _;
    }

    function _useNonces(address player) internal returns (uint256 current) {
        Counters.Counter storage counter = Nonces[player];
        current = counter.current();
        counter.increment();
    }

    function setGodPetProbabilityValue(uint16 val) external override onlyOwner {
        GodPetProbabilityValue = val;
    }

    function getGodPetProbabilityValue() external view override onlyOwner returns(uint16 val) {
        val = GodPetProbabilityValue;
    }

    function setProxy(address proxy) external override onlyOwner {
        Proxy = proxy;
        SceneId = INullsWorldCore(Proxy).newScene(address(this));
    }

    function setTransferProxy(address proxy) external override onlyOwner {
        TransferProxy = ITransferProxy(proxy);
    }

    function setBigPrizePool(address addr) external override onlyOwner {
        BigPrizePool = addr;
    }

    function setPetTokenAndEggToken( address eggToken , address petToken ) external override onlyOwner {
        EggToken = eggToken ;
        PetToken = petToken ;
    }

    function setAfterProccess( address afterAddr ) external override onlyOwner {
        BuyTokenAfter = afterAddr ;
    }

    function getSceneId() external view override returns(uint sceneId) {
        return SceneId;
    }

    function setBuyToken( address token , uint amount ) external override onlyOwner {
        BuyToken memory buyToken = BuyToken({
            amount : amount ,
            isOk : true 
        }) ;
        BuyTokens[ token ] = buyToken ;
    }

    function getPrice(address token) external view override returns(uint price) {
        BuyToken memory buyToken =  BuyTokens[token];
        require(buyToken.isOk, "NullsEggManager/Unsupported token.");
        price = buyToken.amount;
    }

    function notify(uint item , bytes32 key , bytes32 rv) external override isFromProxy returns (bool) {

        bytes32 hv = KeyToHv[key];
        DataInfo memory dataInfo = DataInfos[hv];

        require(dataInfo.total > 0, "NullsEggManager/The data obtained by HV is null");
        require(item == dataInfo.itemId, "NullsEggManager/Item verification failed");
        require(dataInfo.isOk, "NullsEggManager/Do not repeat consumption.");

        if (OpenEggRecords[key].isAvailable) {
            for(uint8 i = 0 ; i < dataInfo.total ; i ++ ) {
                _openOne( i , dataInfo.itemId , dataInfo.player , rv, key) ;
            }
        }       
 
        dataInfo.isOk = false;
        DataInfos[hv] = dataInfo;
        
        return true;
    }

    function _getProbability() internal view returns(uint8) {
        if (GodPetCount < 8) {
            return 8;
        } else if(GodPetCount < 16) {
            return 16;
        } else if(GodPetCount < 32) {
            return 32;
        } else if(GodPetCount < 64) {
            return 64;
        } else if(GodPetCount < 128) {
            return 128;
        } else {
            return 0;
        }
    }

    function _openOne( uint8 index , uint item , address player , bytes32 rv, bytes32 requestKey) internal returns ( uint petid ){
        //random v 
        bytes32 val = keccak256( abi.encode(
            player , 
            item , 
            index , 
            rv 
        )) ;

        uint8 probability = _getProbability();

        if (probability != 0 && uint8(bytes1(val)) % probability == 0) {
            val |= 0xff00000000000000000000000000000000000000000000000000000000000000;
        }

        if (GodPetProbabilityValue != 0) {
            if (uint8(bytes1(val)) != 0xff) {
                GodPetProbability[player] += 1;
                if (GodPetProbability[player] >= GodPetProbabilityValue) {
                    GodPetProbability[player] = 0;
                    val |= 0xff00000000000000000000000000000000000000000000000000000000000000;
                }
            } else {
                GodPetProbability[player] = 0;
            }
        }
        if (uint8(bytes1(val)) == 0xff) {
            GodPetCount++;
        }
        petid = INullsPetToken( PetToken ).mint( player , val ) ;

        //emit Open
        emit NewPet(petid, index , item, player, val , rv, requestKey);
    }

    function registerItem(address pubkey) external override onlyOwnerOrWhiteList {
        uint itemId = INullsWorldCore(Proxy).newItem(SceneId, pubkey, 0);

        emit NewEggItem(itemId, pubkey);
    }

    // approve -> transferFrom
    function buy( uint total , address token ) external override {
        address sender = msg.sender ;
        require( total > 0 , "NullsEggManager/Total is zero.") ;
        //扣款
        BuyToken memory buyToken = BuyTokens[ token ] ;
        require( buyToken.isOk == true , "NullsEggManager/Not allow token." ) ;
        uint amount = total * buyToken.amount ;

        uint serviceProviderAmount = amount / 10;
        uint bigPrizePoolAmount = amount - serviceProviderAmount;

        // transfer to service provider
        TransferProxy.erc20TransferFrom(token, sender, owner(), serviceProviderAmount);

        // transfer to big prize pool
        TransferProxy.erc20TransferFrom(token, sender, BigPrizePool, bigPrizePoolAmount);
        // // transfer to big prize pool
        INullsBigPrizePool(BigPrizePool).transferIn();

        INullsEggToken( EggToken ).mint( sender , total ) ; 

        // after proccess 
        if( BuyTokenAfter != address(0) ) {
            //approve to after 
            // IERC20( token ).approve( address(this) , amount );
            INullsAfterBuyEgg( BuyTokenAfter ).doAfter(sender, total, token, amount );
        }
        emit BuyEgg(sender, total, amount, token);
    } 

    function openMultiple(
        uint total ,
        uint itemId , 
        uint256 deadline
    ) external override {
        require( total > 0 && total <=20 , "NullsEggManager/Use 1-20 at a time.");

        require(block.timestamp <= deadline, "NullsEggManager: expired deadline");
    
        TransferProxy.erc20TransferFrom(EggToken, msg.sender, address(this), total);

        bytes32 hv = keccak256(
            abi.encode(
                "nulls.egg",
                total,
                itemId,
                deadline,
                _useNonces(msg.sender),
                block.chainid
            )
        );       

        bytes32 requestKey = INullsWorldCore(Proxy).getNonce(itemId, hv);

        OpenEggRecords[requestKey] = OpenEggRecord({
            isAvailable: true,
            amount: total
        });

        KeyToHv[requestKey] = hv; 

        DataInfos[hv] = DataInfo({
            total: total,
            itemId: itemId,
            player: msg.sender,
            isOk: true
        });
        emit EggNewNonce(msg.sender, total,itemId, hv, requestKey, deadline);
    }

    function refund(bytes32 requestKey) external {
        bytes32 hv = KeyToHv[requestKey]; 
        DataInfo memory info = DataInfos[hv];
        require(msg.sender == info.player && info.isOk, "NullsEggManager/Illegal operation");
        require(!INullsWorldCore(Proxy).checkRequestKey(requestKey), "NullsEggManager/Refund time is not due");
        OpenEggRecord storage openEggRecord = OpenEggRecords[requestKey];
        require(openEggRecord.isAvailable, "NullsEggManager/No refund");
        IERC20(EggToken).transfer(msg.sender, openEggRecord.amount);
        openEggRecord.isAvailable = false;
        emit RefundEgg(msg.sender, requestKey, openEggRecord.amount);
    }
}
