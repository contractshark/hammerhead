pragma solidity ^0.5.0 || ^0.6.0 || ^0.7.0 || ^0.8.0;

contract Call {
  constructor() public {}

  function theAnswerToLifeTheUniverseAndEverything() public pure returns (int256) {
    return 42;
  }

  function causeReturnValueOfUndefined() public pure returns (bool) {
    require(false);
    return true;
  }
  
  /*!
  * @test {concensus} getCoinbase 
  */
  function getCoinbase() public returns (address){
    return block.coinbase;
  }
}
