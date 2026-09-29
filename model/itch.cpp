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

#include "itch.hpp"

static uint16_t be16(const void* p) { auto b = static_cast<const uint8_t*>(p); return uint16_t((b[0] << 8) | b[1]); }
static uint32_t be32(const void* p) { auto b = static_cast<const uint8_t*>(p); return (uint32_t(be16(b)) << 16) | be16(b + 2); }
static uint64_t be48(const void* p) { auto b = static_cast<const uint8_t*>(p); return (uint64_t(be16(b)) << 32) | be32(b + 2); }
static uint64_t be64(const void* p) { auto b = static_cast<const uint8_t*>(p); return (uint64_t(be32(b)) << 32) | be32(b + 4); }

static int expected_len(char t) {
    switch (t) {
        case 'S': return 12;  case 'R': return 39;  case 'H': return 25;
        case 'Y': return 20;  case 'L': return 26;  case 'V': return 35;
        case 'W': return 12;  case 'K': return 28;  case 'J': return 35;
        case 'h': return 21;  case 'A': return 36;  case 'F': return 40;
        case 'E': return 31;  case 'C': return 36;  case 'X': return 23;
        case 'D': return 19;  case 'U': return 35;  case 'P': return 44;
        case 'Q': return 40;  case 'B': return 19;  case 'I': return 50;
        case 'N': return 20;  case 'O': return 48;
        default:  return 0;
    }
}
parsed parser (const uint8_t* msg, size_t len) {
parsed out{};
    if (len == 0 || size_t(expected_len(char(msg[0]))) != len)    { out.pstat = parsed::PARSESTATUS::BAD; 
    return out;}
    const std::byte* message = reinterpret_cast<const std::byte*>(msg + 11);
    out.type = char(msg[0]);  
    out.location = be16(msg + 1);
    out.tracking_number = be16(msg + 3);
    out.time = int48(be48(msg + 5));
    switch (out.type) {
        case 'A':
        out.order_ref = be64(message);
        out.side = message[8];
        out.shares = be32(&message[9]); 
        std::memcpy(&out.stock, &message[13], 8);
        out.price = be32(&message[21]); 
        break;
        case 'B':
        out.mnum = be64(message);
        break;
        case 'C':
        out.order_ref = be64(message); 
        out.exshare = be32(&message[8]); 
        out.mnum = be64(&message[12]); 
        out.printable = message[20];
        out.execprice = be32(&message[21]);
        break;
        case 'D':
        out.order_ref = be64(message); 
        break;
        case 'E':
        out.order_ref = be64(message); 
        out.exshare = be32(&message[8]); 
        out.mnum = be64(&message[12]);
        break;
        case 'F':
        out.order_ref = be64(message);
        out.side = message[8];
        out.shares = be32(&message[9]);
        std::memcpy(&out.stock, &message[13], 8);
        out.price = be32(&message[21]); 
        std::memcpy(&out.atr, &message[25], 4); 
        break;       
        case 'H':
        std::memcpy(&out.stock, message, 8); 
        std::memcpy(&out.tradestate, &message[8], 1);
        std::memcpy(&out.reserved, &message[9], 1);
        std::memcpy(&out.reason_code, &message[10], 4); 
        break;
        case 'h':
        std::memcpy(&out.stock, message, 8);
        out.market_code = message[8];
        out.halt = message[9];
        break;
        case 'I':
        out.parshar = be64(message);
        out.imb_shares = be64(&message[8]); 
        std::memcpy(&out.imb_dir, &message[16], 1);
        std::memcpy(&out.stock, &message[17], 8);
        out.far_prc = be32(&message[25]); 
        out.near_prc = be32(&message[29]);
        out.cref = be32(&message[33]); 
        std::memcpy(&out.crstype, &message[37], 1);
        std::memcpy(&out.pricevar, &message[38], 1);
        break;
        case 'J':
        std::memcpy(&out.stock, message, 8);
        out.rprc = be32(&message[8]); 
        out.ucllr = be32(&message[12]); 
        out.lcllr = be32(&message[16]); 
        out.ex = be32(&message[20]); 
        break;
        case 'K':
        std::memcpy(&out.stock, message, 8);
        out.reltime = be32(&message[8]); 
        std::memcpy(&out.relqual, &message[12], 1);
        out.ipoprc = be32(&message[13]); 
        break;
        case 'L':
        std::memcpy(&out.MPID, message, 4);
        std::memcpy(&out.stock, &message[4], 8);
        std::memcpy(&out.pmm, &message[12], 1); 
        std::memcpy(&out.mmmm, &message[13], 1);
        std::memcpy(&out.mps, &message[14], 1); 
        break;
        case 'N':
        std::memcpy(&out.stock, message, 8);
        std::memcpy(&out.intflg, &message[8], 1);
        break;
        case 'O':
        std::memcpy(&out.stock, message, 8);
        std::memcpy(&out.opnelg, &message[8], 1);
        out.minprc = be32(&message[9]); 
        out.maxprc = be32(&message[13]); 
        out.nearexp = be32(&message[17]); 
        out.nearext = be64(&message[21]);
        out.lcllr = be32(&message[29]);
        out.ucllr = be32(&message[33]);
        break;
        case 'P':
        out.order_ref = be64(message); 
        std::memcpy(&out.side, &message[8], 1);
        out.shares = be32(&message[9]); 
        std::memcpy(&out.stock, &message[13], 8);
        out.price = be32(&message[21]); 
        out.mnum = be64(&message[25]);
        break;
        case 'Q':
        out.lshare = be64(message); 
        std::memcpy(&out.stock, &message[8], 8);
        out.crsprc = be32(&message[16]); 
        out.mnum = be64(&message[20]);
        std::memcpy(&out.crstype, &message[28], 1);
        break;
        case 'R':
        std::memcpy(&out.stock, message, 8);
        std::memcpy(&out.markcat, &message[8], 1);
        std::memcpy(&out.finstat, &message[9], 1);
        out.rndltsz = be32(&message[10]);
        std::memcpy(&out.rndltsnly, &message[14], 1);
        std::memcpy(&out.issueclar, &message[15], 1);
        std::memcpy(&out.isssubtyp, &message[16], 2);
        std::memcpy(&out.auth, &message[18], 1);
        std::memcpy(&out.shortsalethres, &message[19], 1);
        std::memcpy(&out.ipoflg, &message[20], 1);
        std::memcpy(&out.LULD, &message[21], 1);
        std::memcpy(&out.ETPF, &message[22], 1);
        out.ETPLF = be32(&message[23]);
        std::memcpy(&out.invind, &message[27], 1);
        break;
        case 'S':
        std::memcpy(&out.evntcd, &message[0], 1);
        break;
        case 'U':
        out.ogref = be64(message);
        out.nwref = be64(&message[8]);
        out.shares = be32(&message[16]); 
        out.price = be32(&message[20]);
        break;
        case 'V':
        out.level1 = be64(message); 
        out.level2 = be64(&message[8]); 
        out.level3 = be64(&message[16]);
        break;
        case 'W':
        std::memcpy(&out.breachedlvl, message, 1);
        break;
        case 'X':
        out.order_ref = be64(message);
        out.xshare = be32(&message[8]); 
        break;
        case 'Y':
        std::memcpy(&out.stock, message, 8);
        std::memcpy(&out.regsho, &message[8], 1);
        break;
    }
    out.pstat = parsed::PARSESTATUS::CLEAN;
    return out; 
}

