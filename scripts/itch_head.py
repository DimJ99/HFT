#!/usr/bin/env python3
"""Cut the first N messages out of a Nasdaq binary ITCH file (gzipped or raw).

The output keeps the file framing (2-byte big-endian length before each message),
so it is a valid, small ITCH file for fast tests. Prints a message-type histogram.

    itch_head.py data/20181228.PSX_ITCH_50.gz data/sample.itch -n 1000000
"""
import argparse, collections, gzip, struct, sys

ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
ap.add_argument("src")
ap.add_argument("dst")
ap.add_argument("-n", "--messages", type=int, default=1_000_000)
args = ap.parse_args()

opener = gzip.open if args.src.endswith(".gz") else open
hist = collections.Counter()
count = 0
with opener(args.src, "rb") as fi, open(args.dst, "wb") as fo:
    while count < args.messages:
        hdr = fi.read(2)
        if len(hdr) < 2:
            break
        (n,) = struct.unpack(">H", hdr)
        body = fi.read(n)
        if len(body) < n:
            print("warning: truncated final message dropped", file=sys.stderr)
            break
        fo.write(hdr + body)
        hist[chr(body[0])] += 1
        count += 1

print(f"wrote {count} messages to {args.dst}")
for t, c in sorted(hist.items(), key=lambda kv: -kv[1]):
    print(f"  {t}  {c:>10}")
