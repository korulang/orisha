#!/usr/bin/env bash
# Build HttpArena entry: cold (no profile) or warm (orisha.profile present).
#
#   ./build.sh cold
#   ./build.sh warm baseline          # uses profiles/generated/baseline.profile
#   ./build.sh warm board-mix
#   PUMP=io-uring ./build.sh warm json-comp
#
# Env:
#   KORUC, PUMP (io-uring|linux|default), DATASET_PATH
set -euo pipefail

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:${PATH:-}"

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

PUMP="${PUMP:-default}"
DATASET_PATH="${DATASET_PATH:-./data/dataset.json}"

if command -v koruc >/dev/null 2>&1; then
    KORUC="${KORUC:-koruc}"
elif [ -x "${KORUC:-$HOME/src/koru/zig-out/bin/koruc}" ]; then
    KORUC="${KORUC:-$HOME/src/koru/zig-out/bin/koruc}"
else
    echo "koruc not found" >&2
    exit 1
fi

build_flags=(main.k --release=fast)
case "$PUMP" in
    io-uring) build_flags+=(--build=io-uring) ;;
    linux)    build_flags+=(--build=linux) ;;
    default)  ;;
    *) echo "unknown PUMP=$PUMP (io-uring|linux|default)" >&2; exit 1 ;;
esac

mode="${1:-cold}"
profile_name="${2:-board-mix}"

rm -f orisha.profile
case "$mode" in
    cold)
        echo "==> cold build (no orisha.profile)"
        ;;
    warm)
        gen="$HERE/profiles/generated/${profile_name}.profile"
        echo "==> warm build (profile=$profile_name)"
        python3 "$HERE/workload.py" --profile "$profile_name" --train "$gen"
        cp "$gen" orisha.profile
        ;;
    *)
        echo "usage: $0 cold | warm [profile-name]" >&2
        exit 1
        ;;
esac

echo "==> ${KORUC} ${build_flags[*]}"
DATASET_PATH="$DATASET_PATH" "$KORUC" "${build_flags[@]}" 2>&1 | tee "$HERE/results/last-build.log" | grep -E 'profile:|Built executable|error' || true

if [ "$mode" = "warm" ]; then
    rm -f orisha.profile
fi

echo "==> a.out $(wc -c < a.out) bytes  pump=$PUMP  mode=$mode"
