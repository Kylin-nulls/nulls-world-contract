// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITransferProxy {
    function erc20TransferFrom(address contractAddr, address sender, address recipient, uint256 amount) external;
    function erc721TransferFrom(address contractAddr, address sender, address recipient, uint tokenId) external;
}