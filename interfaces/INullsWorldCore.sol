// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface INullsWorldCore {
    function newItem(uint256 sceneId, address pubkey, uint8 model)
        external
        returns (uint256 itemId);

    function getNonce(
        uint256 itemId,
        bytes32 hv
    ) external returns (bytes32 requestKey);

    function newScene(address addr) external returns (uint256 sceneId);

    function checkRequestKey(
      bytes32 requestKey
    ) external view returns(bool);
}
