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
struct Int48 {
    uint64_t value : 48;
};
struct itch_packer { char type; int16_t location;
    int16_t tracking_number; Int48 time;
    std::byte message[50]; 
};

void parser (itch_packer input) {

    switch (input.type) {
        case "A"



    }

}