#include <cstdio>
#include <cstdint>
#include <fstream>
#include <iterator>
#include <vector>

#include "itch.hpp"

int main(int argc, char** argv) {
    if (argc != 2) { std::fprintf(stderr, "usage: %s FILE.itch\n", argv[0]); return 2; }

    std::ifstream f(argv[1], std::ios::binary);
    if (!f) { std::perror(argv[1]); return 2; }
    std::vector<uint8_t> buf((std::istreambuf_iterator<char>(f)), std::istreambuf_iterator<char>());

    uint64_t count[256] = {}, bad[256] = {};
    uint64_t total = 0, total_bad = 0;
    size_t pos = 0;
    while (pos + 2 <= buf.size()) {
        size_t len = (size_t(buf[pos]) << 8) | buf[pos + 1];
        if (pos + 2 + len > buf.size()) { std::fprintf(stderr, "truncated message at offset %zu\n", pos); break; }
        const uint8_t* msg = &buf[pos + 2];

        parsed p = parser(msg, len);
        uint8_t t = len ? msg[0] : 0;
        count[t]++; total++;
        if (p.pstat == parsed::PARSESTATUS::BAD) { bad[t]++; total_bad++; }

        pos += 2 + len;
    }

    for (int t = 0; t < 256; t++)
        if (count[t]) std::printf("  %c  %10lu  bad %lu\n", t, count[t], bad[t]);
    std::printf("%lu messages, %lu bad\n", total, total_bad);
    return total_bad ? 1 : 0;
}
