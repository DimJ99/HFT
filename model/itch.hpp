// ITCH 5.0 message parser: golden model shared by apps/ and tb/.
#pragma once
#include <cstddef>
#include <cstdint>

struct int48 {
    uint64_t value : 48;
    int48() : value(0) {}
    explicit int48(uint64_t val) : value(val) {}
};

struct parsed {      
    uint64_t order_ref; 
    std::byte side;
    uint32_t shares; 
    uint64_t stock; 
    uint32_t price; 
    uint32_t exshare;
    uint64_t mnum;
    uint32_t execprice;
    std::byte printable;
    uint32_t atr;
    std::byte tradestate;
    std::byte reserved;
    uint32_t reason_code;
    std::byte market_code; 
    std::byte halt;
    uint64_t parshar;
    uint64_t imb_shares;
    std::byte imb_dir;
    uint32_t far_prc;
    uint32_t near_prc;
    uint32_t cref;
    std::byte crstype;
    std::byte pricevar;
    uint32_t rprc;
    uint32_t ucllr;
    uint32_t lcllr;
    uint32_t ex;
    uint32_t reltime;
    std::byte relqual;
    uint32_t ipoprc;
    uint32_t MPID;
    std::byte pmm; 
    std::byte mmmm;
    std::byte mps;  
    std::byte intflg;
    std::byte opnelg;
    uint32_t minprc;
    uint32_t maxprc;
    uint32_t nearexp;
    uint64_t nearext;
    uint32_t crsprc;
    uint64_t lshare;
    std::byte evntcd;
    uint64_t ogref;
    uint64_t nwref;
    uint64_t level1;
    uint64_t level2;
    uint64_t level3;
    std::byte breachedlvl;
    uint32_t xshare;
    std::byte regsho;
    std::byte markcat;
    std::byte finstat;
    uint32_t rndltsz;
    std::byte rndltsnly;
    uint16_t isssubtyp;
    std::byte issueclar;
    std::byte auth;
    std::byte shortsalethres;
    std::byte ipoflg;
    std::byte LULD;
    std::byte ETPF;
    uint32_t ETPLF;
    std::byte invind;
    char type; int16_t location;
    int16_t tracking_number; int48 time;
    enum class PARSESTATUS : char { CLEAN, BAD };
    PARSESTATUS pstat;
};

// msg points at the message type byte (just past the 2-byte file/MoldUDP64 length prefix);
// len is that prefix's value.  Reads nothing beyond msg[len - 1].
parsed parser(const uint8_t* msg, size_t len);
