/// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.6.0 || ^0.7.0 || ^0.8.0;
/// @title ChainId
contract ChainId {
  function getChainId() pure external returns (uint256) {
    uint256 id;
    assembly {
      id := chainid()
    }
    return id;
  }
}
