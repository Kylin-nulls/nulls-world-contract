//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "../interfaces/IZKRandomCallback.sol";
import "../interfaces/IZKRandomCore.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NullsWorldCore is IZKRandomCallback, Ownable {

    // random oracle
    IZKRandomCore ZKRandomCore;

    uint256 GameId;
    mapping(uint256 => uint256) Items;      // itemId -> sceneId 
    address[] Scenes;
    bool GameStatus = true;

    // newItem白名单
    mapping(address => bool) newItemWhiteList;
 
    modifier onlyOwnerOrWhiteList() {
        require(owner() == _msgSender() || newItemWhiteList[_msgSender()] == true, "Ownable: caller is not the owner or white list");
        _;
    }

    modifier onlyZkRandom() {
      require(address(ZKRandomCore) == _msgSender(), "NullsWorldCore/No permission");
      _;
    }

    constructor(address router) {
        ZKRandomCore = IZKRandomCore(router);
    }

    function addNewItemWhiteList(address user) external onlyOwner {
        newItemWhiteList[user] = true;
    }

    function approve(address tokenAddr, uint amount) external onlyOwner {
        require(address(ZKRandomCore) != address(0), "NullsWorldCore/Target account error.");
        IERC20(tokenAddr).approve(address(ZKRandomCore), amount);
    }

    function registerGame(string memory gameName, uint256 depositAmt) external onlyOwner {
        GameId = ZKRandomCore.regist(gameName, address(this), depositAmt);
    }

    function newScene( address addr ) external onlyOwnerOrWhiteList returns (uint sceneId) {
        sceneId = Scenes.length;
        Scenes.push(addr);
    }


    function newItem(
        uint256 sceneId,
        address pubkey,
        uint8 model
    ) external onlyOwnerOrWhiteList returns (uint256 itemId) {
        itemId = ZKRandomCore.newItem(GameId, address(this), pubkey, model);
        Items[itemId] = sceneId;
    }

    function addPubkeyAsync(
        uint256 itemId, 
        address pubkey
    ) external onlyOwnerOrWhiteList {
        ZKRandomCore.modifyItem(itemId, pubkey);
    }

    function applyUnBond() external onlyOwner {
        ZKRandomCore.applyUnBond(GameId);
    }

    function withdrawInZkRandom() external onlyOwner {
        ZKRandomCore.withdraw(GameId);
    }

    function withdraw(address tokenAddr, uint amount) external onlyOwner {
        IERC20(tokenAddr).transfer(msg.sender, amount);
    }

    function publishPrivateKey(uint256 itemId, bytes memory prikey) external onlyOwner {
        ZKRandomCore.publishPrivateKey(itemId, prikey);
    }

    function getNonce(uint256 itemId, bytes32 hv) public returns(bytes32 requestKey) {
       return ZKRandomCore.accept(address(this), itemId, hv);
    }

    function notify(
        uint item,
        bytes32 key,
        bytes32 rv
    ) external override onlyZkRandom returns (bool){
        uint sceneId = Items[item] ;
        address sceneAddr = Scenes[sceneId] ;
        return IZKRandomCallback(sceneAddr).notify(item, key, rv);
    }
 
    function play(
        bytes32 key,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external { 
        ZKRandomCore.generateRandom(key, deadline, v, r, s);
    }

    function checkRequestKey(
      bytes32 requestKey
    ) external view returns(bool) {
        return ZKRandomCore.checkRequestKey(requestKey);
    }

}
