library stringUtils {
    function splitBySlash(string value) public returns (string, string){
        return split(, 0x2F);
    }

    function split(string value, byte separator) public returns (string, string){
        TvmBuilder bFirstHalf;
        TvmBuilder bSecondHalf;
        bool isSlashFound = false;
        bytes stringBytes = bytes(value);
        uint256 stringLength = stringBytes.length;
        for(uint8 i = 0; i < stringLength; i++){
            byte char = stringBytes[i];
            if (!isSlashFound){
                if (char == separator) isSlashFound = true;
                else bFirstHalf.store(char);
            }
            else bSecondHalf.store(char);
        }
        TvmBuilder bFirstHalf_;
        TvmBuilder bSecondHalf_;
        bFirstHalf_.storeRef(bFirstHalf);
        bSecondHalf_.storeRef(bSecondHalf);
        TvmSlice sFirstHalf = bFirstHalf_.toSlice();
        TvmSlice sSecondHalf_ = bSecondHalf_.toSlice();
        return (string(sFirstHalf.decode(bytes)), string(sSecondHalf_.decode(bytes)));
    }
}
