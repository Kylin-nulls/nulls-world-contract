// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../interfaces/ITransferProxy.sol";
import "../../interfaces-external/INullWorldMarket.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract NullWorldMarket is INullWorldMarket, Ownable {
    ITransferProxy TransferProxy;

    mapping(address => Token) SupportedToken;
    mapping(uint256 => SellInfo) PetSellInfos;

    function setTransferProxy(address proxy) external override onlyOwner {
        TransferProxy = ITransferProxy(proxy);
    }

    function setSupportedToken(
        address tokenAddr,
        bool supported,
        uint256 feeRate
    ) external override onlyOwner {
        Token memory token = SupportedToken[tokenAddr];
        token.supported = supported;
        token.feeRate = feeRate;
        SupportedToken[tokenAddr] = token;
    }

    function getSupportedToken(
        address tokenAddr
    ) external override view returns(Token memory tokenInfo) {
        tokenInfo = SupportedToken[tokenAddr];
    }

    function getPetSellInfos(
        uint256 petId
    ) external override view returns(SellInfo memory sellInfo) {
        sellInfo = PetSellInfos[petId];
    }

    function sellPet(
        uint256 petId,
        address tokenAddr,
        uint256 price
    ) external override {
        require(
            SupportedToken[tokenAddr].supported == true,
            "NullsPetTrade/Unsupported token."
        );
        _checkSell(petId);
        SellInfo memory sellInfo = PetSellInfos[petId];

        require(sellInfo.isSell == false, "NullsPetTrade/Do not resell.");

        sellInfo.isSell = true;
        sellInfo.token = tokenAddr;
        sellInfo.price = price;
        sellInfo.seller = msg.sender;
        PetSellInfos[petId] = sellInfo;
        emit SellPet(petId, sellInfo.count, tokenAddr, price, msg.sender);
    }

    function unSellPet(uint256 petId) external override {
        SellInfo memory sellInfo = PetSellInfos[petId];
        require(
            sellInfo.seller == msg.sender,
            "NullsPetTrade/Pet id is illegal."
        );
        _unSellPet(petId);
    }

    function buyPet(uint256 petId) external override {
        SellInfo memory sellInfo = PetSellInfos[petId];
        require(
            sellInfo.isSell,
            "NullsPetTrade/Currently pets do not support buying."
        );
        uint256 amount = sellInfo.price;
        Token memory token = SupportedToken[sellInfo.token];
        uint256 fee = (amount * token.feeRate) / 10000;
        amount -= fee;
        if (fee > 0) {
            TransferProxy.erc20TransferFrom(sellInfo.token, msg.sender, owner(), amount);
        }

        TransferProxy.erc20TransferFrom(sellInfo.token, msg.sender, sellInfo.seller, amount);
        sellInfo.isSell = false;
        sellInfo.count += 1;
        PetSellInfos[petId] = sellInfo;

        _buyPet(sellInfo.seller, msg.sender, petId);

        emit SuccessSell(petId, amount, sellInfo.seller, msg.sender);
    }

    function _unSellPet(uint256 petId) internal {
        SellInfo memory sellInfo = PetSellInfos[petId];
        if (sellInfo.isSell == true) {
            sellInfo.isSell = false;
            PetSellInfos[petId] = sellInfo;
            emit UnSellPet(petId, sellInfo.count, sellInfo.seller);
        }
    }

    function _checkSell(uint256 petId) internal virtual {}

    function _buyPet(
        address from,
        address to,
        uint256 petId
    ) internal virtual {}
}
