// tdata	64	8 bytes of the frame per clock
// tkeep	8	Which bytes in tdata are valid (1 bit per byte). All ones except possibly on the last beat.
// tvalid	1	Data on this cycle is real
// tlast	1	This is the final beat of the frame
// tuser	1+	Usually a bad-frame flag (CRC error). If set on the tlast beat, discard the frame.
// tready	1	Your backpressure signal. The RX side of most MACs ignores it or has no tready at all, because you can't pause the wire. Your parser must keep up at line rate.
#include <cstdio>
#include <cstdlib>
#include <memory>
#include <cstddef>
#include <cstring>
#include <iostream>
#include <cstdint>

struct Int48 {
    uint64_t value : 48;
};
struct itch_packer { char type; int16_t location;
    int16_t tracking_number; Int48 time;
    std::byte message[50]; 
};

static uint16_t be16(const void* p) { auto b = static_cast<const uint8_t*>(p); return uint16_t((b[0] << 8) | b[1]); }
static uint32_t be32(const void* p) { auto b = static_cast<const uint8_t*>(p); return (uint32_t(be16(b)) << 16) | be16(b + 2); }
static uint64_t be64(const void* p) { auto b = static_cast<const uint8_t*>(p); return (uint64_t(be32(b)) << 32) | be32(b + 4); }

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
};


parsed parser (itch_packer input) {
parsed out{};
    switch (input.type) {
        case 'A':
        out.order_ref = be64(input.message);
        out.side = input.message[8];
        out.shares = be32(&input.message[9]); 
        std::memcpy(&out.stock, &input.message[13], 8);
        out.price = be32(&input.message[21]); 
        break;
        case 'B':
        out.mnum = be64(input.message);
        break;
        case 'C':
        out.order_ref = be64(input.message); 
        out.exshare = be32(&input.message[8]); 
        out.mnum = be64(&input.message[12]); 
        out.printable = input.message[20];
        out.execprice = be32(&input.message[21]);
        break;
        case 'D':
        out.order_ref = be64(input.message); 
        break;
        case 'E':
        out.order_ref = be64(input.message); 
        out.exshare = be32(&input.message[8]); 
        out.mnum = be64(&input.message[12]);
        break;
        case 'F':
        out.order_ref = be64(input.message);
        out.side = input.message[8];
        out.shares = be32(&input.message[9]);
        std::memcpy(&out.stock, &input.message[13], 8);
        out.price = be32(&input.message[21]); 
        std::memcpy(&out.atr, &input.message[25], 4); 
        break;       
        case 'H':
        std::memcpy(&out.stock, input.message, 8); 
        std::memcpy(&out.tradestate, &input.message[8], 1);
        std::memcpy(&out.reserved, &input.message[9], 1);
        std::memcpy(&out.reason_code, &input.message[10], 4); 
        break;
        case 'h':
        std::memcpy(&out.stock, input.message, 8);
        out.market_code = input.message[8];
        out.halt = input.message[9];
        break;
        case 'I':
        out.parshar = be64(input.message);
        out.imb_shares = be64(&input.message[8]); 
        std::memcpy(&out.imb_dir, &input.message[16], 1);
        std::memcpy(&out.stock, &input.message[17], 8);
        out.far_prc = be32(&input.message[25]); 
        out.near_prc = be32(&input.message[29]);
        out.cref = be32(&input.message[33]); 
        std::memcpy(&out.crstype, &input.message[37], 1);
        std::memcpy(&out.pricevar, &input.message[38], 1);
        break;
        case 'J':
        std::memcpy(&out.stock, input.message, 8);
        out.rprc = be32(&input.message[8]); 
        out.ucllr = be32(&input.message[12]); 
        out.lcllr = be32(&input.message[16]); 
        out.ex = be32(&input.message[20]); 
        break;
        case 'K':
        std::memcpy(&out.stock, input.message, 8);
        out.reltime = be32(&input.message[8]); 
        std::memcpy(&out.relqual, &input.message[12], 1);
        out.ipoprc = be32(&input.message[13]); 
        break;
        case 'L':
        std::memcpy(&out.MPID, input.message, 4);
        std::memcpy(&out.stock, &input.message[4], 8);
        std::memcpy(&out.pmm, &input.message[12], 1); 
        std::memcpy(&out.mmmm, &input.message[13], 1);
        std::memcpy(&out.mps, &input.message[14], 1); 
        break;
        case 'N':
        std::memcpy(&out.stock, input.message, 8);
        std::memcpy(&out.intflg, &input.message[8], 1);
        break;
        case 'O':
        std::memcpy(&out.stock, input.message, 8);
        std::memcpy(&out.opnelg, &input.message[8], 1);
        out.minprc = be32(&input.message[9]); 
        out.maxprc = be32(&input.message[13]); 
        out.nearexp = be32(&input.message[17]); 
        out.nearext = be64(&input.message[21]);
        out.lcllr = be32(&input.message[29]);
        out.ucllr = be32(&input.message[33]);
        break;
        case 'P':
        out.order_ref = be64(input.message); 
        std::memcpy(&out.side, &input.message[8], 1);
        out.shares = be32(&input.message[9]); 
        std::memcpy(&out.stock, &input.message[13], 8);
        out.price = be32(&input.message[21]); 
        out.mnum = be64(&input.message[25]);
        break;
        case 'Q':
        out.lshare = be64(input.message); 
        std::memcpy(&out.stock, &input.message[8], 8);
        out.crsprc = be32(&input.message[16]); 
        out.mnum = be64(&input.message[20]);
        std::memcpy(&out.crstype, &input.message[28], 1);
        break;
        case 'R':
        std::memcpy(&out.stock, input.message, 8);
        std::memcpy(&out.markcat, &input.message[8], 1);
        std::memcpy(&out.finstat, &input.message[9], 1);
        out.rndltsz = be32(&input.message[10]);
        std::memcpy(&out.rndltsnly, &input.message[14], 1);
        std::memcpy(&out.issueclar, &input.message[15], 1);
        std::memcpy(&out.isssubtyp, &input.message[16], 2);
        std::memcpy(&out.auth, &input.message[18], 1);
        std::memcpy(&out.shortsalethres, &input.message[19], 1);
        std::memcpy(&out.ipoflg, &input.message[20], 1);
        std::memcpy(&out.LULD, &input.message[21], 1);
        std::memcpy(&out.ETPF, &input.message[22], 1);
        out.ETPLF = be32(&input.message[23]);
        std::memcpy(&out.invind, &input.message[27], 1);
        break;
        case 'S':
        std::memcpy(&out.evntcd, &input.message[0], 1);
        break;
        case 'U':
        out.ogref = be64(input.message);
        out.nwref = be64(&input.message[8]);
        out.shares = be32(&input.message[16]); 
        out.price = be32(&input.message[20]);
        break;
        case 'V':
        out.level1 = be64(input.message); 
        out.level2 = be64(&input.message[8]); 
        out.level3 = be64(&input.message[16]);
        break;
        case 'W':
        std::memcpy(&out.breachedlvl, input.message, 1);
        break;
        case 'X':
        out.order_ref = be64(input.message);
        out.xshare = be32(&input.message[8]); 
        break;
        case 'Y':
        std::memcpy(&out.stock, input.message, 8);
        std::memcpy(&out.regsho, &input.message[8], 1);
        break;
    }
    return out; 
}