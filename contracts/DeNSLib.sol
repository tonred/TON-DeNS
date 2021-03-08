pragma ton-solidity ^0.37.0;

struct Records{
    address A;
    string ADNL;
    string[] TXT;
}

struct WhoIsInfo {
    address parent;
    string path;
    string name;
    address owner;
    uint32 expiresAt;
    Records records;
}

enum Phase {OPEN, CONFIRMATION, CLOSE}

struct PhaseTime {
    uint32 startTime;
    uint32 finishTime;
}

enum RegistrationTypes { OwnerOnly, Auction, Instant }

library CertificateErrors {
    uint constant IS_NOT_OWNER = 101;
    uint constant IS_EXT_MSG = 102;
    uint constant IS_NOT_ROOT = 103;
    uint constant IS_NOT_SUBDOMAIN = 104;

    uint constant INVALID_DOMAIN_NAME = 110;

    uint constant NOT_ALLOWED_REGISTRATION_TYPE = 120;
    uint constant INVALID_REGISTRATION_TYPE = 121;

    uint constant NOT_ENOUGH_TOKENS_FOR_INSTANT_BUY = 130;
    uint constant DURATION_LARGER_MAX_ALLOWED_FOR_INSTANT_BUY = 131;
    uint constant DURATION_LARGER_ROOT_CERT_EXPIRES = 132;
}
