//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface INullsAfterPk {

    function doAfterPk(address user, address payToken, uint payAmount ) external ;

}