/// SPDX-License-Identifier: Apache-2.0

pragma solidity >=0.5.17 <0.8.0;

/// @title Event Debug Interface
/// @description A contract you can inherit from that has some useful Events to print statements.
/// @version 1.0.0


contract EventsDebug {
    event LogAddress(address _msg);
    event LogInt(int _msg);
    event LogString(string _msg);
    event LogUint(uint256 _msg);
    event LogBytes(bytes _msg);
    event LogBytes32(bytes32 _msg);
    event LogBool(bool _msg);
}
