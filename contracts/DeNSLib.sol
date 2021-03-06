pragma ton-solidity ^0.37.0;

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

enum Phase {OPEN, CONFIRMATION, CLOSE}

struct PhaseTime {
    uint32 startTime;
    uint32 finishTime;
}


library CertificateErrors {
    uint constant IS_NOT_OWNER = 101;
    uint constant IS_EXT_MSG = 102;
    uint constant IS_NOT_ROOT = 103;

    uint constant INSTANT_REGISTRATION_NOT_ALLOWED = 120;
    uint constant REGISTRATION_BY_AUCTION_NOT_ALLOWED = 121;
    uint constant REGISTRATION_BY_OWNER_NOT_ALLOWED = 122;
    uint constant INVALID_REGISTRATION_TYPE = 122;
}

library RegistrationTypes {
    uint8 constant OWNER_ONLY = 0;
    uint8 constant AUCTION = 1;
    uint8 constant INSTANT = 2;
}
