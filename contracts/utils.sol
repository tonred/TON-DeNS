library stringUtils {
    function splitBySlash(string domainName) public returns (string, string){
        TvmBuilder bFirstHalf;
        TvmBuilder bSecondHalf;
        bool isSlashFound = false;
        bytes domainNameBytes = bytes(domainName);
        uint256 domainNameLength = domainNameBytes.length;
        for(uint8 i = 0; i < domainNameLength; i++){
            byte char = domainNameBytes[i];
            if (!isSlashFound){
                if (char == 0x2F) isSlashFound = true;
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
