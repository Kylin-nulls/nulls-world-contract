//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract IdoToken is ERC20 {
    address Owner;
    address Oper;
    uint8 Decimals ;

    modifier onlyOwner() {
        require(msg.sender == Owner, "NullsERC20Token/No role.");
        _;
    }

    modifier onlyOper() {
        require(msg.sender == Oper, "NullsERC20Token/No oper role.");
        _;
    }

    function decimals() public view override returns (uint8) {
        return Decimals;
    }

    constructor(string memory name_, string memory symbol_, uint8 decimals_)
        ERC20(name_, symbol_)
    {
        Owner = msg.sender;
        Oper = msg.sender;
        Decimals = decimals_;
    }

    function modifierOwner(address owner) external onlyOwner {
        Owner = owner;
    }

    function modifierOper(address oper) external onlyOwner {
        Oper = oper;
    }

    function mint(address player, uint256 total) external onlyOper {
        _mint(player, total);
    }

    function burn(address player, uint256 total) external onlyOper {
        _burn(player, total);
    }
    function test()external view returns (address) {
        return Oper;
    }
}
