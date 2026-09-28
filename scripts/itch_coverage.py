#!/usr/bin/env python3
"""Build a parser-coverage sample: the first N messages of every ITCH 5.0 type in a day.

All symbols are kept (the parser doesn't care which stock a message is for), so this
file is for parser tests, not book tests; use itch_filter.py for a single-symbol book.
Scans the whole day and prints how often each type appeared, checks every message
length against the spec, and lists spec types that never showed up; those need
hand-written directed tests.

    itch_coverage.py data/07302019.NASDAQ_ITCH50.gz data/coverage.itch -n 500
"""
import argparse, collections, gzip, shutil, subprocess, sys, time

# type: (name, length in bytes excluding the 2-byte file length prefix), ITCH 5.0 spec
SPEC = {
    "S": ("System Event", 12),
    "R": ("Stock Directory", 39),
    "H": ("Stock Trading Action", 25),
    "Y": ("Reg SHO Restriction", 20),
    "L": ("Market Participant Position", 26),
    "V": ("MWCB Decline Level", 35),
    "W": ("MWCB Status", 12),
    "K": ("IPO Quoting Period Update", 28),
    "J": ("LULD Auction Collar", 35),
    "h": ("Operational Halt", 21),
    "A": ("Add Order", 36),
    "F": ("Add Order with MPID", 40),
    "E": ("Order Executed", 31),
    "C": ("Order Executed with Price", 36),
    "X": ("Order Cancel", 23),
    "D": ("Order Delete", 19),
    "U": ("Order Replace", 35),
    "P": ("Trade (non-cross)", 44),
    "Q": ("Cross Trade", 40),
    "B": ("Broken Trade", 19),
    "I": ("NOII", 50),
    "N": ("Retail Price Improvement Indicator", 20),
    "O": ("DLCR Price Discovery", 48),
}

ap = argparse.ArgumentParser(description=__doc__.splitlines()[0],
                             formatter_class=argparse.RawDescriptionHelpFormatter, epilog=__doc__)
ap.add_argument("src")
ap.add_argument("dst")
ap.add_argument("-n", "--per-type", type=int, default=500, help="messages kept per type (default 500)")
args = ap.parse_args()

if args.src.endswith(".gz") and shutil.which("pigz"):
    proc = subprocess.Popen(["pigz", "-dc", args.src], stdout=subprocess.PIPE, bufsize=1 << 24)
    src = proc.stdout
else:
    proc = None
    src = gzip.open(args.src, "rb") if args.src.endswith(".gz") else open(args.src, "rb")

seen = collections.Counter()
kept = collections.Counter()
bad_len = collections.Counter()
limit = args.per_type
buf = b""
pos = 0
total = 0
t0 = t_report = time.time()

with open(args.dst, "wb") as out:
    while True:
        chunk = src.read(1 << 24)
        if not chunk:
            break
        buf = buf[pos:] + chunk
        pos = 0
        end = len(buf)
        while pos + 2 <= end:
            n = (buf[pos] << 8) | buf[pos + 1]
            if pos + 2 + n > end:
                break
            t = chr(buf[pos + 2])
            seen[t] += 1
            spec = SPEC.get(t)
            if spec is None or spec[1] != n:
                bad_len[(t, n)] += 1
            if kept[t] < limit:
                out.write(buf[pos:pos + 2 + n])
                kept[t] += 1
            pos += 2 + n
        total = sum(seen.values())
        if time.time() - t_report > 10:
            t_report = time.time()
            print(f"  ...{total / 1e6:.0f}M scanned", file=sys.stderr)

if proc:
    proc.wait()

print(f"{total} messages scanned in {time.time() - t0:.0f}s, {sum(kept.values())} kept -> {args.dst}\n")
print(f"  {'type':<5}{'name':<36}{'len':>4}{'in day':>14}{'kept':>7}")
for t, (name, length) in SPEC.items():
    mark = "" if seen[t] else "   <-- missing"
    print(f"  {t:<5}{name:<36}{length:>4}{seen[t]:>14}{kept[t]:>7}{mark}")
for (t, n), c in sorted(bad_len.items()):
    what = "unknown type" if t not in SPEC else f"length {n}, spec says {SPEC[t][1]}"
    print(f"  WARNING: {c} messages of type {t!r}: {what}")
missing = [t for t in SPEC if not seen[t]]
if missing:
    print(f"\nnot in this day: {' '.join(missing)}. Cover these with directed tests built from the spec.")
