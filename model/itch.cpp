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

struct Int48 {
    uint64_t value : 48;
};
struct itch_packer { char type; int16_t location;
    int16_t tracking_number; Int48 time;
    std::byte message[50]; 
};

struct parsed {      uint64_t order_ref; 
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
    uint64_t stock;
    std::byte market_code; 
    std::byte halt;};
parsed parser (itch_packer input) {
parsed out;
    switch (input.type) {
        case 'A':
        std::memcpy(&out.order_ref, input.message, 8);
        out.side = input.message[8];
        std::memcpy(&out.shares, &input.message[9], 4);
        std::memcpy(&out.stock, &input.message[13], 8);
        std::memcpy(&out.price, &input.message[21], 4);
        break;
        case 'B':
        std::memcpy(&out.order_ref, input.message, 8);
        break;
        case 'C':
        std::memcpy(&out.order_ref, input.message, 8);
        std::memcpy(&out.exshare, &input.message[8], 4);
        std::memcpy(&out.mnum, &input.message[12], 8);
        out.printable = input.message[20];
        std::memcpy(&out.execprice, &input.message[21], 4);
        break;
        case 'D':
        std::memcpy(&out.order_ref, input.message, 8);
        break;
        case 'E':
        std::memcpy(&out.order_ref, input.message, 8);
        std::memcpy(&out.exshare, &input.message[8], 4);
        std::memcpy(&out.mnum, &input.message[12], 8);
        break;
        case 'F':
        std::memcpy(&out.order_ref, input.message, 8);
        out.side = input.message[8];
        std::memcpy(&out.shares, &input.message[9], 4);
        std::memcpy(&out.stock, &input.message[13], 8);
        std::memcpy(&out.price, &input.message[21], 4);
        std::memcpy(&out.atr, &input.message[25], 8);
        case 'H':
        std::memcpy(&out.order_ref, input.message, 8);
        std::memcpy(&out.tradestate, &input.message[8], 1);
        std::memcpy(&out.reserved, &input.message[9], 1);
        std::memcpy(&out.reserved, &input.message[10], 4);
        case 'h':
        std::memcpy(&out.stock, input.message, 8);
        out.market_code = input.message[8];
        out.halt = input.message[9];
        case 'I':
        
        case 'J':
        case 'K':
        case 'L':
        case 'N':
        case 'O':
        case 'P':
        case 'Q':
        case 'R':
        case 'S':
        case 'U':
        case 'V':
        case 'W':
        case 'X':
        case 'Y':
    }

}