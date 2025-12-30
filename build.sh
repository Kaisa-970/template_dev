#!/bin/bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./build.sh [-r|-d] [-h]

Options:
  -r            Build Release (default)
  -d            Build Debug
  -h            Show help

Default build dirs:
  Release -> build/release
  Debug   -> build/debug

Env overrides:
  GENERATOR     CMake generator name (e.g. "Ninja")
EOF
}

BUILD_TYPE="Release"

while getopts ":rdB:h" opt; do
  case "$opt" in
    r) BUILD_TYPE="Release" ;;
    d) BUILD_TYPE="Debug" ;;
    h) usage; exit 0 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage; exit 2 ;;
    :)  echo "Missing argument for: -$OPTARG" >&2; usage; exit 2 ;;
  esac
done
shift $((OPTIND - 1))


case "$BUILD_TYPE" in
Release) BUILD_DIR="build/release" ;;
Debug)   BUILD_DIR="build/debug" ;;
*)       BUILD_DIR="build" ;;
esac


# 优先 Ninja，否则回退
if [[ -n "${GENERATOR:-}" ]]; then
  GEN="$GENERATOR"
else
  if command -v ninja >/dev/null 2>&1; then
    GEN="Ninja"
  else
    GEN="Unix Makefiles"
  fi
fi

NUM_WORKERS=$(nproc 2>/dev/null || echo 1)

cmake -S . -B "$BUILD_DIR" -G "$GEN" -DCMAKE_BUILD_TYPE="$BUILD_TYPE"
cmake --build "$BUILD_DIR" -j "$NUM_WORKERS"