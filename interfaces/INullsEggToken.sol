//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface INullsEggToken {

    function mint( address player , uint total ) external ;

    function burn( address player , uint total ) external ;

}