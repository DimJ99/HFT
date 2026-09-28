#!/usr/bin/env bash
# Report which tools are available and at what version. Exit 1 if a required one is missing.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/scripts/env.sh" 2>/dev/null

fail=0
check() {  # check <required|optional> <cmd> <version-cmd...>
    local need=$1 cmd=$2; shift 2
    local out
    if command -v "$cmd" >/dev/null 2>&1 && out=$("$@" 2>&1); then
        printf '  \033[32mok\033[0m   %-12s %s\n' "$cmd" "$(head -1 <<<"$out")"
    elif command -v "$cmd" >/dev/null 2>&1; then
        printf '  \033[31mBROKE\033[0m %-11s %s\n' "$cmd" "$(head -1 <<<"$out" | cut -c1-90)"
        [ "$need" = required ] && fail=1
    elif [ "$need" = required ]; then
        printf '  \033[31mMISS\033[0m %-12s (required)\n' "$cmd"; fail=1
    else
        printf '  \033[33m--\033[0m   %-12s (optional)\n' "$cmd"
    fi
}

echo "C++ / build"
check required g++        g++ --version
check optional clang++    clang++ --version
check required make       make --version
check optional cmake      cmake --version
check optional ccache     ccache --version
for h in zlib.h lz4.h; do
    if echo "#include <$h>" | g++ -E -x c++ - >/dev/null 2>&1; then
        printf '  \033[32mok\033[0m   %-12s header\n' "$h"
    else
        printf '  \033[31mMISS\033[0m %-12s (required for FST waves; make setup installs it)\n' "$h"; fail=1
    fi
done
echo "RTL sim / lint"
check required verilator  verilator --version
echo "Formal"
check required yosys      yosys -V
check required sby        sh -c 'echo "SymbiYosys ($(command -v sby))"'
check optional boolector  boolector --version
check optional yices-smt2 yices-smt2 --version
check optional z3         z3 --version
echo "Waveforms"
check optional gtkwave    sh -c 'gtkwave --version 2>/dev/null | grep -m1 -i gtkwave'
check optional surfer     surfer --version
echo "Synthesis / timing"
check optional vivado     vivado -version
echo "Python"
check required python3    python3 --version

v=$(verilator --version 2>/dev/null | awk '{print $2}')
if [ -n "$v" ] && [ "${v%%.*}" -lt 5 ]; then
    echo "WARNING: Verilator $v is < 5.x; SVA/timing support is limited. Run 'make setup'."; fail=1
fi
case "$(command -v verilator)" in
    "$ROOT"/tools/*) ;;
    *) [ -n "$v" ] && echo "note: using system verilator, not tools/oss-cad-suite (run 'make setup')" ;;
esac
exit $fail
