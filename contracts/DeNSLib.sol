pragma ton-solidity >=0.37.0;

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

enum VoteCountModel {
    Undefined,
    Majority,
    SoftMajority,
    SuperMajority,
    Other,
    Reserved,
    Last
}

enum RegistrationTypes { OwnerOnly, Auction, Instant }

enum AuctionPhase {OPEN, CONFIRMATION, CLOSE}

struct AuctionPhaseTime {
    uint32 startTime;
    uint32 finishTime;
}

library DeNsErrors {
    uint16 constant IS_NOT_OWNER = 101;
    uint16 constant IS_EXT_MSG = 102;
    uint16 constant IS_NOT_ROOT = 103;
    uint16 constant IS_NOT_SUBDOMAIN = 104;
    uint16 constant IS_NOT_STORAGE = 105;
    uint16 constant IS_NOT_SMV = 106;
    uint16 constant IS_NOT_PROPOSAL = 106;
    uint16 constant IS_NOT_AUCTION = 107;
    uint16 constant DOMAIN_IS_EXPIRED = 108;

    uint16 constant INVALID_DOMAIN_NAME = 110;

    uint16 constant NOT_ALLOWED_REGISTRATION_TYPE = 120;
    uint16 constant INVALID_REGISTRATION_TYPE = 121;

    uint16 constant NOT_ENOUGH_TOKENS_FOR_INSTANT_BUY = 130;
    uint16 constant DURATION_LARGER_MAX_ALLOWED_FOR_INSTANT_BUY = 131;
    uint16 constant DURATION_LARGER_ROOT_CERT_EXPIRES = 132;

    uint16 constant NOT_ENOUGH_TOKENS_FOR_AUCTION = 140;


}
