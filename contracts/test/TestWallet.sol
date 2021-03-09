pragma ton-solidity ^0.37.0;


contract TesWallet {
    constructor() public {
        tvm.accept();
    }
    function sendTransaction(
        address dest,
        uint128 value,
        bool bounce,
        uint8 flags,
        TvmCell payload
    ) public pure {
        tvm.accept();
        dest.transfer(value, bounce, flags, payload);
    }


    fallback() external {}

    receive() external {}
}
