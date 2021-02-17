pragma solidity >=0.6.0;


struct Records{
    address A;
    string ADNL;
    string[] TXT;
}

struct WhoIsInfo {
    string absoluteDomainName;
    address parent;
    address owner;
    uint32 expiresAt;
    Records records;
}


library CertificateErrors {
    uint constant IS_NOT_OWNER = 101;
    uint constant IS_EXT_MSG = 102;
    uint constant IS_NOT_ROOT = 103;
}

library RegistrationTypes {
    uint constant DISABLED = 0;
    uint constant AUCTION = 1;
    uint constant ONWER_ONLY = 2;
    uint constant INSTANT = 3;
}
