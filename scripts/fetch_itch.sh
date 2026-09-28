#!/usr/bin/env bash
# Download a Nasdaq historical ITCH 5.0 file into data/ and verify its md5.
#   scripts/fetch_itch.sh [VENUE] [FILE]
#   VENUE: nasdaq | bx | psx          (default psx: smallest full day, ~850 MB gz)
#   FILE : name on emi.nasdaq.com     (default: 20181228.PSX_ITCH_50.gz)
# `scripts/fetch_itch.sh list nasdaq` prints the available files for a venue.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE=https://emi.nasdaq.com/ITCH

dir_for() {
    case "$1" in
        nasdaq) echo "Nasdaq%20ITCH" ;;
        bx)     echo "Nasdaq%20BX%20ITCH" ;;
        psx)    echo "Nasdaq%20PSX%20ITCH" ;;
        *) echo "unknown venue '$1' (nasdaq|bx|psx)" >&2; exit 1 ;;
    esac
}

if [ "${1:-}" = list ]; then
    d=$(dir_for "${2:-nasdaq}")
    curl -fsSL "$BASE/$d/" | sed 's/<br>/\n/gi' \
        | sed -nE 's#.* ([0-9]+) <A HREF="[^"]*/([^"/]+\.gz)".*#\2  \1#p' \
        | awk '{printf "%-32s %8.2f GB\n", $1, $2/1e9}' | sort
    exit 0
fi

VENUE=${1:-psx}
FILE=${2:-20181228.PSX_ITCH_50.gz}
d=$(dir_for "$VENUE")
mkdir -p "$ROOT/data"
cd "$ROOT/data"

echo "fetching $FILE from $VENUE (resumable)"
curl -fL -C - --progress-bar -o "$FILE" "$BASE/$d/$FILE"
if curl -fsSL -o "$FILE.md5sum" "$BASE/$d/$FILE.md5sum"; then
    want=$(awk '{print $1}' "$FILE.md5sum")
    have=$(md5sum "$FILE" | awk '{print $1}')
    [ "$want" = "$have" ] && echo "md5 ok" || { echo "md5 MISMATCH ($have != $want)"; exit 1; }
fi

# Stock locate codes for the same day (maps locate IDs -> tickers), best-effort.
day=$(echo "$FILE" | grep -oE '^[0-9]{8}')
if [ -n "$day" ]; then
    case "$day" in 20*) ymd=$day ;; *) ymd="${day:4:4}${day:0:2}${day:2:2}" ;; esac
    prefix=$VENUE; [ "$VENUE" = nasdaq ] && prefix=ndq
    loc="${prefix}_stocklocate_${ymd}.txt"
    curl -fsSL -o "$loc" "$BASE/Stock_Locate_Codes/$loc" 2>/dev/null \
        && echo "got $loc" || { rm -f "$loc"; echo "(no locate file for $ymd)"; }
fi
