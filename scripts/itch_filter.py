#!/usr/bin/env python3
"""Cut one symbol's messages out of a Nasdaq binary ITCH 5.0 file.

Keeps, in original order:
  - every market-wide message (locate 0): System Event 'S', MWCB levels 'V', ...
  - the symbol's Stock Directory ('R') message, which tells you its locate code for the day
  - every other message whose stock locate matches that symbol

Stops reading at --until, so the rest of the day is never decompressed. By default
everything from the start of the day is kept, so orders that rest in the book from
pre-market are present when they are later executed or cancelled. Starting later
with --from leaves those references dangling.

Output keeps the file framing (2-byte big-endian length before each message).

    itch_filter.py data/07302019.NASDAQ_ITCH50.gz data/AAPL.itch
    itch_filter.py SRC DST --symbol MSFT --until 16:00
"""
import argparse, collections, gzip, shutil, subprocess, sys, time


def hhmm_to_ns(s):
    h, m = s.split(":")
    return (int(h) * 3600 + int(m) * 60) * 1_000_000_000


def ns_to_hms(ns):
    s = ns // 1_000_000_000
    return f"{s // 3600:02d}:{s % 3600 // 60:02d}:{s % 60:02d}.{ns % 1_000_000_000:09d}"


def open_src(path):
    """Decompress with pigz when available (several times faster than Python's gzip)."""
    if not path.endswith(".gz"):
        return open(path, "rb"), None
    if shutil.which("pigz"):
        p = subprocess.Popen(["pigz", "-dc", path], stdout=subprocess.PIPE, bufsize=1 << 24)
        return p.stdout, p
    return gzip.open(path, "rb"), None


ap = argparse.ArgumentParser(description=__doc__.splitlines()[0],
                             formatter_class=argparse.RawDescriptionHelpFormatter, epilog=__doc__)
ap.add_argument("src")
ap.add_argument("dst")
ap.add_argument("--symbol", default="AAPL")
ap.add_argument("--from", dest="start", default=None, metavar="HH:MM",
                help="drop symbol messages before this time (default: keep from start of day)")
ap.add_argument("--until", default="10:00", metavar="HH:MM",
                help="stop at this time (default 10:00, half an hour after the open)")
ap.add_argument("-n", "--max", type=int, default=0, help="stop after writing this many messages")
args = ap.parse_args()

sym = args.symbol.upper().encode().ljust(8)     # ITCH stock field: 8 bytes, space padded
t_from = hhmm_to_ns(args.start) if args.start else 0
t_until = hhmm_to_ns(args.until)

src, proc = open_src(args.src)
hist = collections.Counter()
scanned = written = 0
locate = None
first_ts = last_ts = None
buf = b""
pos = 0
t0 = t_report = time.time()

with open(args.dst, "wb") as out:
    done = False
    while not done:
        chunk = src.read(1 << 24)
        if not chunk:
            break
        buf = buf[pos:] + chunk
        pos = 0
        end = len(buf)
        while pos + 2 <= end:
            n = (buf[pos] << 8) | buf[pos + 1]
            if pos + 2 + n > end:
                break                                  # message continues in next chunk
            m = pos + 2                                # message body: type, locate, tracking, ts48, ...
            typ = buf[m]
            loc = (buf[m + 1] << 8) | buf[m + 2]
            ts = int.from_bytes(buf[m + 5:m + 11], "big")
            scanned += 1
            if ts >= t_until:
                done = True
                break
            keep = False
            if loc == 0:                               # market-wide: 'S' system event, 'V' MWCB levels, ...
                keep = True
            elif typ == 0x52 and buf[m + 11:m + 19] == sym:   # 'R' stock directory for our symbol
                locate = loc
                keep = True
            elif loc == locate and ts >= t_from:
                keep = True
            if keep:
                out.write(buf[pos:m + n])
                hist[chr(typ)] += 1
                written += 1
                first_ts = ts if first_ts is None else first_ts
                last_ts = ts
                if args.max and written >= args.max:
                    done = True
                    break
            pos = m + n
        if time.time() - t_report > 5:
            t_report = time.time()
            print(f"  ...{scanned / 1e6:.0f}M scanned, feed time {ns_to_hms(ts)[:8]}", file=sys.stderr)

if proc:
    proc.kill()
    proc.wait()

if locate is None:
    print(f"error: no Stock Directory ('R') message for {args.symbol} before {args.until}", file=sys.stderr)
    sys.exit(1)

print(f"{args.symbol}: locate {locate}, {written} of {scanned} messages kept "
      f"({time.time() - t0:.0f}s) -> {args.dst}")
if first_ts is not None:
    print(f"  time span {ns_to_hms(first_ts)} .. {ns_to_hms(last_ts)}")
for t, c in sorted(hist.items(), key=lambda kv: -kv[1]):
    print(f"  {t}  {c:>10}")
