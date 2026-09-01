#!/usr/bin/env bash
# Run HttpArena validate.sh against a Docker image built from local checkouts.
#
# Requires: Docker running, Homebrew bash 5+ (profiles.sh uses declare -A).
#
#   ./validate-local.sh              build + validate
#   ./validate-local.sh --skip-build reuse httparena-orisha tag
#
# Env:
#   SRC_ROOT     parent of koru/, koru-libs/, orisha/ (default: ../.. from here → ~/src)
#   HTTPARENA_ROOT
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC_ROOT="${SRC_ROOT:-$HERE/../..}"
HTTPARENA_ROOT="${HTTPARENA_ROOT:-$SRC_ROOT/HttpArena}"
IMAGE_NAME="${IMAGE_NAME:-httparena-orisha}"
BASH5="${BASH5:-/opt/homebrew/bin/bash}"

# validate.sh uses grep -P for frag result parsing; macOS BSD grep lacks -P.
if [ -d /opt/homebrew/opt/grep/libexec/gnubin ]; then
    export PATH="/opt/homebrew/opt/grep/libexec/gnubin:$PATH"
fi

SKIP_BUILD=0
if [ "${1:-}" = "--skip-build" ]; then
    SKIP_BUILD=1
    shift
fi

if ! docker info >/dev/null 2>&1; then
    echo "Docker daemon is not running — start Docker Desktop first." >&2
    exit 1
fi

if [ ! -x "$BASH5" ]; then
    echo "bash 5+ required for HttpArena profiles.sh — brew install bash" >&2
    exit 1
fi

for d in koru koru-libs orisha; do
    if [ ! -d "$SRC_ROOT/$d" ]; then
        echo "missing checkout: $SRC_ROOT/$d" >&2
        exit 1
    fi
done

if [ ! -x "$HTTPARENA_ROOT/scripts/validate.sh" ]; then
    echo "HttpArena not found at $HTTPARENA_ROOT" >&2
    exit 1
fi

mkdir -p "$HERE/results"
STAMP="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
LOG="$HERE/results/validate-local-$STAMP.txt"

if [ "$SKIP_BUILD" = "0" ]; then
    echo "==> building $IMAGE_NAME from local trees ($SRC_ROOT)"
    docker build -f "$HERE/Dockerfile.local" -t "$IMAGE_NAME" "$SRC_ROOT" 2>&1 | tee "$HERE/results/validate-local-build-$STAMP.log"
fi

echo "==> validate.sh orisha (VALIDATE_SKIP_BUILD=1)"
(
    cd "$HTTPARENA_ROOT"
    VALIDATE_SKIP_BUILD=1 "$BASH5" ./scripts/validate.sh orisha
) 2>&1 | tee "$LOG"

echo "==> log: $LOG"
