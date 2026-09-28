#!/usr/bin/env bash
# One-shot environment bring-up for Ubuntu 24.04 (native or WSL2).
#   1. apt packages: C++ toolchain, build helpers, waveform viewer, python
#   2. YosysHQ OSS CAD Suite into ./tools: Verilator, Yosys, SymbiYosys, SMT solvers
# Re-running is safe; finished steps are skipped.
#
# Env overrides:
#   OSS_CAD_VERSION=YYYY-MM-DD   pin a suite release (default: latest)
#   SKIP_APT=1                   don't touch system packages
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="$ROOT/tools"
SUITE="$TOOLS/oss-cad-suite"

log() { printf '\033[1;34m[setup]\033[0m %s\n' "$*"; }

# ---- 1. system packages ------------------------------------------------------
APT_PKGS=(
    build-essential g++ clang clang-format clang-tidy gdb
    make cmake ninja-build ccache pkg-config
    git curl wget ca-certificates pigz
    python3 python3-venv python3-pip
    libfmt-dev zlib1g-dev liblz4-dev
    gtkwave
)
if [ "${SKIP_APT:-0}" != 1 ]; then
    missing=()
    for p in "${APT_PKGS[@]}"; do
        dpkg -s "$p" >/dev/null 2>&1 || missing+=("$p")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        log "apt install: ${missing[*]}"
        sudo apt-get update
        sudo apt-get install -y --no-install-recommends "${missing[@]}"
    else
        log "apt packages already installed"
    fi
fi

# ---- 2. OSS CAD Suite --------------------------------------------------------
case "$(uname -m)" in
    x86_64)  arch=x64 ;;
    aarch64) arch=arm64 ;;
    *) echo "unsupported arch $(uname -m)" >&2; exit 1 ;;
esac

if [ -z "${OSS_CAD_VERSION:-}" ]; then
    OSS_CAD_VERSION="$(curl -fsSI https://github.com/YosysHQ/oss-cad-suite-build/releases/latest \
        | tr -d '\r' | sed -n 's#^location: .*/tag/##Ip')"
fi
[ -n "$OSS_CAD_VERSION" ] || { echo "could not resolve OSS CAD Suite version" >&2; exit 1; }

if [ -f "$SUITE/.version" ] && [ "$(cat "$SUITE/.version")" = "$OSS_CAD_VERSION" ]; then
    log "OSS CAD Suite $OSS_CAD_VERSION already installed"
else
    url="https://github.com/YosysHQ/oss-cad-suite-build/releases/download/${OSS_CAD_VERSION}/oss-cad-suite-linux-${arch}-${OSS_CAD_VERSION//-/}.tgz"
    log "downloading OSS CAD Suite $OSS_CAD_VERSION"
    mkdir -p "$TOOLS"
    tmp="$(mktemp -d "$TOOLS/.dl.XXXX")"
    trap 'rm -rf "$tmp"' EXIT
    curl -fL --progress-bar -o "$tmp/suite.tgz" "$url"
    log "extracting"
    tar -xzf "$tmp/suite.tgz" -C "$tmp"
    rm -rf "$SUITE"
    mv "$tmp/oss-cad-suite" "$SUITE"
    echo "$OSS_CAD_VERSION" > "$SUITE/.version"
fi

# ---- 2b. Surfer ----------------------------------------------------------------
# The suite's bundled surfer needs a newer glibc than Ubuntu 24.04 ships; use upstream's build.
if [ "$arch" = x64 ] && ! "$TOOLS/bin/surfer" --version >/dev/null 2>&1; then
    log "installing Surfer waveform viewer"
    mkdir -p "$TOOLS/bin"
    stmp="$(mktemp -d "$TOOLS/.dl.XXXX")"
    curl -fsSL -o "$stmp/a.zip" "https://gitlab.com/surfer-project/surfer/-/jobs/artifacts/main/download?job=linux_build"
    python3 -m zipfile -e "$stmp/a.zip" "$stmp/a"
    python3 -m zipfile -e "$stmp/a/surfer_linux.zip" "$stmp/b"
    install -m 755 "$stmp/b/surfer" "$TOOLS/bin/surfer"
    rm -rf "$stmp"
fi

# ---- 3. python venv (latency / P&L analysis, plotting) ---------------------
if [ ! -x "$TOOLS/venv/bin/python" ]; then
    log "creating python venv"
    python3 -m venv "$TOOLS/venv"
fi
"$TOOLS/venv/bin/pip" install -q --upgrade pip
"$TOOLS/venv/bin/pip" install -q -r "$ROOT/scripts/requirements.txt"

log "done. Run 'make doctor' to verify, or 'source scripts/env.sh' for an interactive shell."
