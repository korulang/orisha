#!/usr/bin/env bash
# Local wrk harness for the HttpArena oracle routes.
#
#   ./bench.sh              build (ReleaseFast), start server, wrk all endpoints
#   ./bench.sh pipeline     one endpoint only
#   ./bench.sh --no-build   reuse ./a.out
#   ./bench.sh --serve-only start server and wait (manual wrk)
#
# Env:
#   KORUC       path to koruc (default: koruc on PATH, then ~/src/koru/zig-out/bin/koruc)
#   PORT        cleartext listen port (default 8080)
#   DURATION    wrk -d (default 10s)
#   CONNECTIONS wrk -c (default 256)
#   THREADS     wrk -t (default 4)
#   DATASET_PATH path to dataset.json (default ./data/dataset.json)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

PORT="${PORT:-8080}"
DURATION="${DURATION:-10s}"
CONNECTIONS="${CONNECTIONS:-256}"
THREADS="${THREADS:-4}"
DATASET_PATH="${DATASET_PATH:-./data/dataset.json}"
BUILD=1
SERVE_ONLY=0
ENDPOINTS=()

while [ $# -gt 0 ]; do
    case "$1" in
        --no-build) BUILD=0 ;;
        --serve-only) SERVE_ONLY=1 ;;
        -h|--help)
            sed -n '2,18p' "$0" | sed 's/^# \?//'
            exit 0
            ;;
        pipeline|baseline|json)
            ENDPOINTS+=("$1")
            ;;
        *)
            echo "unknown argument: $1" >&2
            exit 1
            ;;
    esac
    shift
done

[ ${#ENDPOINTS[@]} -eq 0 ] && ENDPOINTS=(pipeline baseline json)

if command -v koruc >/dev/null 2>&1; then
    KORUC="${KORUC:-koruc}"
elif [ -x "${KORUC:-$HOME/src/koru/zig-out/bin/koruc}" ]; then
    KORUC="${KORUC:-$HOME/src/koru/zig-out/bin/koruc}"
else
    echo "koruc not found — build koru first or set KORUC=" >&2
    exit 1
fi

command -v wrk >/dev/null 2>&1 || {
    echo "wrk not found — install: brew install wrk" >&2
    exit 1
}

kill_ports() {
    lsof -ti:"$PORT",8081 2>/dev/null | xargs kill 2>/dev/null || true
    sleep 0.5
}

wait_ready() {
    local i
    for i in $(seq 1 50); do
        if curl -sf "http://127.0.0.1:${PORT}/pipeline" >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.1
    done
    echo "server did not become ready on :${PORT}" >&2
    return 1
}

url_for() {
    case "$1" in
        pipeline) echo "http://127.0.0.1:${PORT}/pipeline" ;;
        baseline) echo "http://127.0.0.1:${PORT}/baseline11?a=13&b=42" ;;
        json)     echo "http://127.0.0.1:${PORT}/json/10?m=1" ;;
        *)        echo "unknown endpoint: $1" >&2; return 1 ;;
    esac
}

run_wrk() {
    local name="$1" url="$2"
    echo ""
    echo "==> wrk ${name}: ${url}"
    echo "    -t${THREADS} -c${CONNECTIONS} -d${DURATION}"
    wrk -t"$THREADS" -c"$CONNECTIONS" -d"$DURATION" "$url"
}

SERVER_PID=""
cleanup() {
    if [ -n "$SERVER_PID" ]; then
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
    kill_ports
}
trap cleanup EXIT INT TERM

kill_ports

if [ "$BUILD" -eq 1 ]; then
    echo "==> building with ${KORUC} --release=fast"
    DATASET_PATH="$DATASET_PATH" "$KORUC" main.k --release=fast >/dev/null
fi

[ -x ./a.out ] || { echo "./a.out missing — run without --no-build" >&2; exit 1; }

echo "==> starting server (DATASET_PATH=${DATASET_PATH})"
DATASET_PATH="$DATASET_PATH" ./a.out &
SERVER_PID=$!
wait_ready
echo "==> ready on http://127.0.0.1:${PORT}"

if [ "$SERVE_ONLY" -eq 1 ]; then
    echo "press Ctrl+C to stop"
    wait "$SERVER_PID"
    exit 0
fi

for ep in "${ENDPOINTS[@]}"; do
    run_wrk "$ep" "$(url_for "$ep")"
done

echo ""
echo "==> done"
