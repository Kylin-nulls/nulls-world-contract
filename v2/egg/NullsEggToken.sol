//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "../../interfaces/INullsEggToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract NullsEggToken is ERC20, INullsEggToken {

    address Owner ;
    address Oper ;
    uint8 Decimals = 0;

    modifier onlyOwner() {
        require( msg.sender == Owner , "NullsWorldToken/No role." );
        _ ; 
    }

    modifier onlyOper() {
        require( msg.sender == Oper , "NullsWorldToken/No oper role." );
        _ ;
    }

    function decimals() public view override returns (uint8) {
        return Decimals;
    }

    constructor() ERC20("NullsEgg Token ","EGG") {
        Owner = msg.sender ;
        Oper = msg.sender ;
    }

    function modifierOwner( address owner ) external onlyOwner {
        Owner = owner ;
    }

    function modifierOper( address oper ) external onlyOwner {
        Oper = oper ;
    }

    function mint( address player , uint total ) external override onlyOper {
        _mint( player , total );
    }

    function burn( address player , uint total ) external override onlyOper {
        _burn( player , total );
    }

}
