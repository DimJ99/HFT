#include <cstdio>
#include <cstdlib>
#include <memory>
#include "Vitch.h"
#include "verilated.h"
#include "verilated_vcd_c.h" 
 

static int failures = 0;
#define CHECK_EQ(actual, expected, msg)                                        \
    do {                                                                       \
        if ((actual) != (expected)) {                                          \
            std::printf("FAIL: %s (expected %d, got %d)\n", msg,               \
                        (int)(expected), (int)(actual));                       \
            failures++;                                                        \
        }                                                                      \
    } while (0)
    
    struct Harness ();