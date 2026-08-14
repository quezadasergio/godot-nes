#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
export PATH="$HOME/Library/Python/3.9/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

JOBS="${JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || nproc)}"
TARGET="${1:-macos}"

if [[ ! -f thirdparty/godot-cpp/SConstruct ]]; then
  echo "Initialize submodules: git submodule update --init --recursive"
  exit 1
fi

case "$TARGET" in
  macos|osx)
    scons platform=macos target=template_debug api_version=4.7 arch=arm64 -j"$JOBS"
    ;;
  macos-release)
    scons platform=macos target=template_release api_version=4.7 arch=arm64 -j"$JOBS"
    ;;
  web)
    if ! command -v emcc >/dev/null 2>&1; then
      echo "emcc is not in PATH. Activate emsdk: source emsdk_env.sh"
      exit 1
    fi
    scons platform=web target=template_release api_version=4.7 arch=wasm32 threads=no -j"$JOBS"
    ;;
  web-debug)
    scons platform=web target=template_debug api_version=4.7 arch=wasm32 threads=no -j"$JOBS"
    ;;
  linux)
    scons platform=linux target=template_debug api_version=4.7 -j"$JOBS"
    ;;
  *)
    echo "Usage: ./build.sh [macos|macos-release|web|web-debug|linux]"
    exit 1
    ;;
esac
