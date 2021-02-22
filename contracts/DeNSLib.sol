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

    uint constant INSTANT_REGISTRATION_NOT_ALLOWED = 120;
    uint constant REGISTRATION_BY_AUCTION_NOT_ALLOWED = 121;
    uint constant REGISTRATION_BY_OWNER_NOT_ALLOWED = 122;
}

library RegistrationTypes {
    uint constant OWNER_ONLY = 0;
    uint constant AUCTION = 1;
    uint constant INSTANT = 2;
}
