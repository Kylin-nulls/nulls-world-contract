//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface INullsAfterBuyEgg {

    function doAfter(address user, uint total , address payToken , uint payAmount ) external ;

}