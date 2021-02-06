/// SPDX-License-Identifier: Apache-2.0
/// @title Contract Shark Verify
/// @version v1.0.0+rc1 
pragma solidity >=0.4.24 < 0.7.0;


/** verification helper */
contract ContractSharkVerificationUtils {
     // account wiht big ether balance
    address public constant _CONTRACT_SHARK_CREATOR   = 0xafFEaFFEAFfeAfFEAffeaFfEAfFEaffeafFeAFfE; 
     //user account with big Ether balance (origin for seed input)
    address public constant _CONTRACT_SHARK_ACCOUNT_0 = 0xAaaaAaAAaaaAAaAAaAaaaaAAAAAaAaaaAaAaaAA0; 
     // user account with 0 Ether balance
    address public constant _CONTRACT_SHARK_ACCOUNT_1 = 0xAaAAAaaAAAAAAaaAAAaaaaAaAaAAAAaAAaAaAaA1;  
     //user account with big Ether balance
    address public constant _CONTRACT_SHARK_ACCOUNT_2 = 0xAaAaaAAAaAaaAaAaAaaAAaAaAAAAAaAAAaaAaAa2;  
     //contract that just returns normally (with big Ether balance)
    address public constant _CONTRACT_SHARK_ACCOUNT_3 = 0xaaaaAaAaaAAaAaaaaAaAAAAAaAAAaAaaaAAaAaa3; 
     //contract that fails by reverting (with big Ether balance)
    address public constant _CONTRACT_SHARK_ACCOUNT_4 = 0xAaaaAaaAaAAaaaAaaAAaaAaaAaAaAaAAAAAaaaa4; 
     //contract that fails by jumping to destination 0 (with big Ether balance)
    address public constant _CONTRACT_SHARK_ACCOUNT_5 = 0xAAaaaaAaaAaaaAAAAAaAAaAAaaaaaAaAAAaAaaA5; 

    event AssertionFailed(string message);

    uint private callDepth = 0;

    modifier _cshark_wrapped_function {
        _cshark_startCall();
        if (_cshark_isOuterCall()) _cshark_ContractInvariant_snapshot();
        _;
        if (_cshark_isOuterCall()) _cshark_ContractInvariant_check();
        _cshark_endCall();
    }

    function _cshark_init() internal {
        //override
        revert("override this method!");
    }

    function _cshark_ContractInvariant_snapshot() internal {
        //override
        revert("override this method!");
    }

    function _cshark_ContractInvariant_check() internal {
        //override
        // perform checks
        revert("override this method!");
    }

    function _cshark_startCall() internal {
        (callDepth++);  //cshark-silence-overflow
    }

    function _cshark_endCall() internal {
        (callDepth--);  //cshark-silence-underflow
    }

    function _cshark_isOuterCall() internal view returns (bool) {
        return (callDepth == 1);
    }

    function _cshark_equals(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))) );
    }


// @dev always check contract invariants also for illegal calls
    function() external _cshark_wrapped_function() {}  
}
