#include <cstdio>
#include <cstdlib>
#include <cstdint>
#include <fstream>
#include <iterator>
#include <memory>
#include <random>
#include <string>
#include <vector>
#include "Vitch_parser.h"
#include "verilated.h"
#if VM_TRACE_FST
#include "verilated_fst_c.h"
#endif
#include "itch.hpp"

static int failures = 0;
#define CHECK_EQ(actual, expected, msg)                                        \
    do {                                                                       \
        if ((actual) != (expected)) {                                          \
            std::printf("FAIL: %s (expected %d, got %d)\n", msg,               \
                        (int)(expected), (int)(actual));                       \
            failures++;                                                        \
        }                                                                      \
    } while (0)


struct Harness {
    std::unique_ptr<VerilatedContext> ctx;
    std::unique_ptr<Vitch_parser> dut;
#if VM_TRACE_FST
    std::unique_ptr<VerilatedFstC> trace;
#endif
    std::mt19937_64 rng;
    uint64_t cycle = 0;

    Harness(int argc, char** argv) : ctx(new VerilatedContext) {
        ctx->commandArgs(argc, argv);
        dut.reset(new Vitch_parser{ctx.get()});
        rng.seed(plusarg_u64("seed", 1));
#if VM_TRACE_FST
        ctx->traceEverOn(true);
        trace.reset(new VerilatedFstC);
        dut->trace(trace.get(), 99);
        trace->open("waves.fst");
#endif
    }

    ~Harness() {
        dut->final();
#if VM_TRACE_FST
        trace->close();
#endif
    }

    // "+name=value" on the command line, or "" if absent
    std::string plusarg(const char* name) {
        std::string key = std::string(name) + "=";
        std::string hit = ctx->commandArgsPlusMatch(key.c_str());
        return hit.empty() ? "" : hit.substr(key.size() + 1);    // drop "+name="
    }
    uint64_t plusarg_u64(const char* name, uint64_t dflt) {
        std::string v = plusarg(name);
        return v.empty() ? dflt : std::stoull(v);
    }

    // One full clock period. Set inputs before calling; read outputs after.
    void tick() {
        dut->clk = 0;
        dut->eval();
        dump();
        dut->clk = 1;
        dut->eval();
        dump();
        cycle++;
    }

    void reset(int cycles = 4) {
        dut->rst = 1;
        dut->s_tvalid = 0;
        for (int i = 0; i < cycles; i++) tick();
        dut->rst = 0;
    }
    
// Testbench for rtl/itch_parser.sv.   make sim BLOCK=itch_parser [ITCH=data/coverage.itch SEED=n TRACE=0]
//
// tdata	64	8 bytes of the frame per clock
// tkeep	8	Which bytes in tdata are valid (1 bit per byte). All ones except possibly on the last beat.
// tvalid	1	Data on this cycle is real
// tlast	1	This is the final beat of the frame
// tuser	1+	Usually a bad-frame flag (CRC error). If set on the tlast beat, discard the frame.
// ---- packet 0: msgs [0, 1] ----
// TDATA=0x1F00000000530C00  TKEEP=0xFF  TLAST=0  // [0] S starts lane 0
// TDATA=0x27005100F0D9CE1A  TKEEP=0xFF  TLAST=0  // [0] ends lane 5; [1] R starts lane 6
// TDATA=0xCE1A1F0000010052  TKEEP=0xFF  TLAST=0
// TDATA=0x204C504141E8F3D9  TKEEP=0xFF  TLAST=0
// TDATA=0x0000004E51202020  TKEEP=0xFF  TLAST=0
// TDATA=0x4E4E50205A434E64  TKEEP=0xFF  TLAST=0
// TDATA=0x004E000000004E31  TKEEP=0Tx7F  LAST=1  // [1] ends lane 6

// // ---- packet 1: msgs [2] ----
// TDATA=0x1F00000100481900  TKEEP=0xFF  TLAST=0  // [2] H starts lane 0
// TDATA=0x504141D0F7D9CE1A  TKEEP=0xFF  TLAST=0
// TDATA=0x202054202020204C  TKEEP=0xFF  TLAST=0
// TDATA=0x0000000000202020  TKEEP=0x07  TLAST=1  // [2] ends lane 2

// // ---- packet 2: msgs [3, 4, 5] ----
// TDATA=0x1F00000100412400  TKEEP=0xFF  TLAST=0  // [3] A starts lane 0
// TDATA=0x000000B8FBD9CE1A  TKEEP=0xFF  TLAST=0
// TDATA=0x000042E903000000  TKEEP=0xFF  TLAST=0
// TDATA=0x20204C5041416400  TKEEP=0xFF  TLAST=0
// TDATA=0x280094E01C002020  TKEEP=0xFF  TLAST=0  // [3] ends lane 5; [4] F starts lane 6
// TDATA=0xCE1A1F0000010046  TKEEP=0xFF  TLAST=0
// TDATA=0x0000000000A0FFD9  TKEEP=0xFF  TLAST=0
// TDATA=0xC800000053EA0300  TKEEP=0xFF  TLAST=0
// TDATA=0x202020204C504141  TKEEP=0xFF  TLAST=0
// TDATA=0x4F43534788E21C00  TKEEP=0xFF  TLAST=0  // [4] ends lane 7 (exact beat boundary)
// TDATA=0x1F00000100451F00  TKEEP=0xFF  TLAST=0  // [5] E starts lane 0
// TDATA=0x0000008803DACE1A  TKEEP=0xFF  TLAST=0
// TDATA=0x000000E903000000  TKEEP=0xFF  TLAST=0
// TDATA=0x1300000000000032  TKEEP=0xFF  TLAST=0
// TDATA=0x0000000000000089  TKEEP=0x01  TLAST=1  // [5] ends lane 0

// // ---- packet 3: msgs [6, 7] ----
// TDATA=0x1F00000100432400  TKEEP=0xFF  TLAST=0  // [6] C starts lane 0
// TDATA=0x0000007007DACE1A  TKEEP=0xFF  TLAST=0
// TDATA=0x000000EA03000000  TKEEP=0xFF  TLAST=0
// TDATA=0x1300000000000064  TKEEP=0xFF  TLAST=0
// TDATA=0x1700C0E11C00598A  TKEEP=0xFF  TLAST=0  // [6] ends lane 5; [7] X starts lane 6
// TDATA=0xCE1A1F0000010058  TKEEP=0xFF  TLAST=0
// TDATA=0x0000000000580BDA  TKEEP=0xFF  TLAST=0
// TDATA=0x0032000000EA0300  TKEEP=0x7F  TLAST=1  // [7] ends lane 6

// // ---- packet 4: msgs [8, 9] ----  <-- ERROR
// TDATA=0x1F00000100552300  TKEEP=0xFF  TLAST=0  // [8] U starts lane 0
// TDATA=0x000000400FDACE1A  TKEEP=0xFF  TLAST=0
// TDATA=0x000000E903000000  TKEEP=0xFF  TLAST=0
// TDATA=0x000000EB03000000  TKEEP=0xFF  TLAST=0
// TDATA=0x441300F8E01C004B  TKEEP=0xFF  TLAST=0  // [8] ends lane 4; [9] D starts lane 5
// TDATA=0xDACE1A1F00000100  TKEEP=0xFF  TLAST=0
// TDATA=0x0000000000002813  TKEEP=0xFF  TLAST=0
// TDATA=0x000000000000EB03  TKEEP=0x01  TLAST=1  // [9] should end lane 1, TKEEP should be 0x03

    void example () { 
        //------------------------------PACKET 1 
        dut->s_tvalid = 1; 
        dut->s_tdata = 0x1F00000000530C00;
        dut->s_tkeep =  0xFF; 
        tick();
        dut->s_tdata = 0x27005100F0D9CE1A;
        dut->s_tkeep =  0xFF; 
        tick();
        dut->s_tdata = 0x27005100F0D9CE1A;
        dut->s_tkeep =  0xFF; 
        tick();
        dut-> s_tdata = 0xCE1A1F0000010052;
        dut->s_tkeep =  0xFF; 
        tick();
        dut-> s_tdata = 0x204C504141E8F3D9;
        dut->s_tkeep =  0xFF; 
        tick();
        dut-> s_tdata = 0x0000004E51202020;
        dut->s_tkeep =  0xFF; 
        tick();
        dut-> s_tdata = 0x4E4E50205A434E64;
        dut->s_tkeep =  0xFF; 
        tick();
        dut-> s_tdata = 0x004E000000004E31;
        dut->s_tkeep =  0x7F; 
        dut->s_tvalid = 1;
        tick();
        // --------------------- PACKET 2 
        
    }
private:
    void dump() {
        ctx->timeInc(1);
#if VM_TRACE_FST
        trace->dump(ctx->time());
#endif
    }
};
// tready

static std::vector<uint8_t> read_file(const std::string& path) {
    std::ifstream f(path, std::ios::binary);
    if (!f) { std::perror(path.c_str()); std::exit(2); }
    return {std::istreambuf_iterator<char>(f), std::istreambuf_iterator<char>()};
}

int main(int argc, char** argv) {
    Harness h(argc, argv);

    std::string itch_path = h.plusarg("itch");
    std::vector<uint8_t> stream;    // length-prefixed ITCH: [len BE16][msg]...
    if (!itch_path.empty()) stream = read_file(itch_path);
    std::printf("itch_parser tb: seed=%lu itch=%s (%zu bytes)\n",
                (unsigned long)h.plusarg_u64("seed", 1),
                itch_path.empty() ? "(none)" : itch_path.c_str(), stream.size());

    h.reset();

    // TODO driver:     pack `stream` into 8-byte beats on s_tdata/s_tkeep/s_tlast (byte 0 -> tdata[7:0]),
    //                  with random s_tvalid gaps from h.rng.
    // TODO monitor:    each tick, capture parsed messages from the DUT output ports.
    // TODO scoreboard: walk `stream` with parser(&stream[pos + 2], len) and compare field by field.
    for (int i = 0; i < 10; i++) h.tick();

    std::printf("%s: %d failures after %lu cycles\n", failures ? "FAIL" : "PASS",
                failures, (unsigned long)h.cycle);
    return failures ? 1 : 0;
}
