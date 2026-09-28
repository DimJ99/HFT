# Source this to put the project toolchain on PATH:   source scripts/env.sh
# (The Makefile does the equivalent automatically.)
_hft_root="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
if [ -d "$_hft_root/tools/oss-cad-suite/bin" ]; then
    case ":$PATH:" in
        *":$_hft_root/tools/oss-cad-suite/bin:"*) ;;
        *) export PATH="$_hft_root/tools/oss-cad-suite/bin:$PATH" ;;
    esac
else
    echo "env.sh: tools/oss-cad-suite not found; run 'make setup'" >&2
fi
case ":$PATH:" in
    *":$_hft_root/tools/bin:"*) ;;
    *) export PATH="$_hft_root/tools/bin:$PATH" ;;
esac
export HFT_ROOT="$_hft_root"
unset _hft_root
if [ -d "$HFT_ROOT/tools/venv/bin" ]; then
    case ":$PATH:" in
        *":$HFT_ROOT/tools/venv/bin:"*) ;;
        *) export PATH="$HFT_ROOT/tools/venv/bin:$PATH" ;;
    esac
fi
