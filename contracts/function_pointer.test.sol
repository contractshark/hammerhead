/// SPDX-License-Identifier: Apache-2.0

pragma solidity >=0.4.22 <0.6.0;

contract Oracle {
    struct Request {
        bytes data;
        function(uint) external callback;
    }
    function(uint, uint) call = reply;
    Request[] requests;
    event NewRequest(uint);
    function query(bytes memory data, function(uint) external callback) public {
        requests.push(Request(data, callback));
        emit NewRequest(requests.length - 1);
    }
    function reply(uint requestID, uint response) public {
        // Here goes the check that the reply comes from a trusted source
        requests[requestID].callback(response);
    }
}

contract OracleUser {
    Oracle constant oracle = Oracle(0x1234567); // known contract
    uint exchangeRate;
    function buySomething() public {
        oracle.query("USD", this.oracleResponse);
    }
    function oracleResponse(uint response) public {
        require(
                msg.sender == address(oracle),
                "Only oracle can call this."
        );
        exchangeRate = response;
    }
}
