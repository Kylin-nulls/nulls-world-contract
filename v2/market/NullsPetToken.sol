// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./NullWorldMarket.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NullsPetToken is ERC721, Ownable, NullWorldMarket {
    using Counters for Counters.Counter;
    Counters.Counter private TokenIds;

    address Oper;
    string BaseURI = "https://nulls.world/pets/";

    mapping(uint256 => bytes32) public Types; //Pet type , 0xff is god pet.

    modifier onlyOper() {
        require(msg.sender == Oper, "NullsPetToken/No oper role.");
        _;
    }

    constructor() ERC721("NullsPetToken", "NullsPet") {
        Oper = msg.sender;
    }

    function modifyOper(address oper) external onlyOwner {
        Oper = oper;
    }

    function mint(address player, bytes32 tv)
        external
        onlyOper
        returns (uint256 tokenId)
    {
        tokenId = _useToken();
        Types[tokenId] = tv;
        _mint(player, tokenId);
    }

    function _useToken() internal returns (uint256 tid) {
        tid = TokenIds.current();
        TokenIds.increment();
    }

    function setBaseURI(string memory uri) public onlyOwner {
        BaseURI = uri;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return BaseURI;
    }

    function _checkSell(uint256 petId) internal view override {
        require(
            _isApprovedOrOwner(_msgSender(), petId),
            "ERC721: transfer caller is not owner nor approved"
        );
    }

    function _buyPet(
        address from,
        address to,
        uint256 petId
    ) internal override {
        _transfer(from, to, petId);
    }

    function _beforeTokenTransfer(
        address ,
        address ,
        uint256 petId
    ) internal override {
        _unSellPet(petId);
    }
}
