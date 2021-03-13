pragma solidity 0.7.1;
pragma experimental ABIEncoderV2;

contract OrchidSender {
    address owner_;

    constructor(address owner) {
        owner_ = owner;
    }

    struct Send {
        address recipient;
        uint256 amount;
    }

    function sendv(address token, Send[] calldata sends) external {
        require(owner_ == msg.sender);
        for (uint i = sends.length; i != 0; ) {
            Send calldata send = sends[--i];
            (bool _s, bytes memory _d) = address(token).call(
                abi.encodeWithSignature("transfer(address,uint256)", send.recipient, send.amount));
            require(_s && (_d.length == 0 || abi.decode(_d, (bool))));
        }
    }
}
