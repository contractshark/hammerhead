pragma solidity ^0.6.1;

// ----------------------------------------------------------------------------
// BokkyPooBah's MakerDAO Pricefeed Adaptor v1.00
//
// Converts MakerDAO's pricefeed on the Ethereum mainnet at
//   https://etherscan.io/address/0x81FE72B5A8d1A857d176C3E7d5Bd2679A9B85763
//
// https://github.com/bokkypoobah/Optino
//
// SPDX-License-Identifier: MIT
//
// Enjoy.
//
// (c) BokkyPooBah / Bok Consulting Pty Ltd 2020. The MIT Licence.
// ----------------------------------------------------------------------------

import "MakerDAOPriceFeed.sol";
import "PriceFeedAdaptor.sol";

// ----------------------------------------------------------------------------
// MakerDAO Pricefeed Adaptor
// ----------------------------------------------------------------------------
contract MakerDAOPricefeedAdaptor is PriceFeedAdaptor {
    address public sourceAddress;

    constructor(address _sourceAddress) public {
        sourceAddress = _sourceAddress;
    }

    function spot() external view override returns (uint256, bool) {
        (bytes32 _value, bool hasValue) = MakerDAOPriceFeed(sourceAddress).peek();
        return (uint256(_value), hasValue);
    }
}
