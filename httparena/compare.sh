#!/usr/bin/env zsh
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:${PATH:-}"
# Same-machine wrk comparison: Orisha HttpArena entry vs a minimal Go stdlib reference,
# plus HttpArena board numbers for context (different hardware, load generator, workload).
#
#   ./compare.sh
#   DURATION=10s CONNECTIONS=256 THREADS=4 ./compare.sh
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

DURATION="${DURATION:-10s}"
CONNECTIONS="${CONNECTIONS:-256}"
THREADS="${THREADS:-4}"
DATASET_PATH="${DATASET_PATH:-./data/dataset.json}"
ORISHA_PORT="${ORISHA_PORT:-8080}"
REF_PORT="${REF_PORT:-8090}"
STAMP="$(/bin/date -u +%Y-%m-%dT%H-%M-%SZ)"
OUT="$HERE/results/compare-${STAMP}.txt"
mkdir -p "$HERE/results"

if command -v koruc >/dev/null 2>&1; then
    KORUC="${KORUC:-koruc}"
elif [ -x "${KORUC:-$HOME/src/koru/zig-out/bin/koruc}" ]; then
    KORUC="${KORUC:-$HOME/src/koru/zig-out/bin/koruc}"
else
    echo "koruc not found" >&2
    exit 1
fi
command -v wrk >/dev/null 2>&1 || { echo "wrk not found" >&2; exit 1; }
WRK="${WRK:-$(command -v wrk)}"
command -v go >/dev/null 2>&1 || { echo "go not found (needed for stdlib reference)" >&2; exit 1; }
PYTHON="${PYTHON:-$(command -v python3)}"
[ -n "$PYTHON" ] || { echo "python3 not found (needed for board context)" >&2; exit 1; }

log() { printf '%s\n' "$*" >>"$OUT"; print -r -- "$*"; }

rps_from_wrk() {
    "$WRK" -t"$THREADS" -c"$CONNECTIONS" -d"$DURATION" "$1" 2>&1 \
        | /usr/bin/awk '/Requests\/sec/ {gsub(/,/,"",$2); print $2; exit}' \
        || echo 0
}

kill_ports() {
    lsof -ti:"$ORISHA_PORT","$REF_PORT",8081 2>/dev/null | xargs kill 2>/dev/null || true
    /bin/sleep 0.5
}

wait_ready() {
    local port="$1" i
    for i in {1..50}; do
        if curl -sf "http://127.0.0.1:${port}/pipeline" >/dev/null 2>&1; then
            return 0
        fi
        /bin/sleep 0.1
    done
    log "ERROR: nothing answered GET /pipeline on :${port} within 5s"
    return 1
}

ORISHA_PID=""
REF_PID=""
cleanup() {
    [ -n "$ORISHA_PID" ] && kill "$ORISHA_PID" 2>/dev/null || true
    [ -n "$REF_PID" ] && kill "$REF_PID" 2>/dev/null || true
    wait "$ORISHA_PID" 2>/dev/null || true
    wait "$REF_PID" 2>/dev/null || true
    kill_ports
}
trap cleanup EXIT INT TERM

: > "$OUT"
log "Orisha HttpArena — honest comparison snapshot"
log "stamp: $STAMP"
log "host: $(/usr/sbin/sysctl -n machdep.cpu.brand_string 2>/dev/null || uname -m) / $(/usr/sbin/sysctl -n hw.ncpu 2>/dev/null || echo '?') cores"
log "wrk: -t${THREADS} -c${CONNECTIONS} -d${DURATION}"
log ""

kill_ports

log "==> building Orisha (ReleaseFast)"
DATASET_PATH="$DATASET_PATH" "$KORUC" main.k --release=fast >>"$OUT" 2>&1

log "==> building Go stdlib reference"
( cd "$HERE/refs" && CGO_ENABLED=0 go build -o minimal minimal.go ) >>"$OUT" 2>&1

log "==> starting servers"
DATASET_PATH="$DATASET_PATH" ./a.out >>"$OUT" 2>&1 &
ORISHA_PID=$!
"$HERE/refs/minimal" >>"$OUT" 2>&1 &
REF_PID=$!
wait_ready "$ORISHA_PORT" || exit 1
wait_ready "$REF_PORT" || exit 1

typeset -A REF_RPS ORISHA_RPS
for entry in \
    "pipeline|/pipeline" \
    "baseline GET|/baseline11?a=13&b=42" \
    "json slice|/json/10?m=1"; do
    label="${entry%%|*}"
    path="${entry#*|}"

    ref_url="http://127.0.0.1:${REF_PORT}${path}"
    orisha_url="http://127.0.0.1:${ORISHA_PORT}${path}"

    if [ "$label" = "json slice" ]; then
        log ""
        log "--- ${label} (Orisha only — reference server has no /json) ---"
        rps="$(rps_from_wrk "$orisha_url")"
        ORISHA_RPS["$label"]="$rps"
        log "  Orisha: ${rps} req/s"
        continue
    fi

    log ""
    log "--- ${label} ---"
    ref_rps="$(rps_from_wrk "$ref_url")"
    orisha_rps="$(rps_from_wrk "$orisha_url")"
    REF_RPS["$label"]="$ref_rps"
    ORISHA_RPS["$label"]="$orisha_rps"
    ratio="$(/usr/bin/awk -v o="$orisha_rps" -v g="$ref_rps" 'BEGIN { if (g>0) printf "%.0f%%", 100*o/g; else print "n/a" }')"
    log "  Go net/http :${REF_PORT}  ${ref_rps} req/s"
    log "  Orisha      :${ORISHA_PORT}  ${orisha_rps} req/s  (${ratio} of Go on this box)"
done

log ""
log "==> HttpArena board context (NOT measured here — reference only)"
log "Board machine: Threadripper PRO 3995WX, 64 cores pinned, Ubuntu 24.04, gcannon @4096 conns"
log "Our wrk run:   $(/usr/sbin/sysctl -n machdep.cpu.brand_string 2>/dev/null || uname -m), wrk -t${THREADS} -c${CONNECTIONS}, GET-only baseline, no gcannon POST mix, no -p16 pipelining"
log ""

LB_DATA="${HTTPARENA_LB:-$HERE/../../HttpArena/site/leaderboard/data.js}"
"$PYTHON" - <<PY | while read -r line; do log "$line"; done
import json, re, os, sys
path = os.path.expanduser("${LB_DATA}")
if not os.path.isfile(path):
    print(f"  (HttpArena leaderboard not found at {path} — skip board context)")
    raise SystemExit(0)
text = open(path).read()
m = re.search(r"window\.LB_DATA = JSON\.parse\('(.+)'\);", text, re.S)
raw = m.group(1).encode('utf-8').decode('unicode_escape')
data = json.loads(raw)
meta = data['meta']
results = data['results']

def top(profile, n=8):
    rows = sorted(results[f"{profile}-4096"], key=lambda r: r['rps'], reverse=True)
    print(f"  {profile} @4096 conns (gcannon, mixed workload per profile spec):")
    for row in rows[:n]:
        name = meta.get(row['fw'], {}).get('display_name', row['fw'])
        print(f"    {row['rps']:>12,.0f}  {name}")
    med = sorted(r['rps'] for r in results[f"{profile}-4096"])
    print(f"    median {med[len(med)//2]:,.0f} across {len(med)} entries")
    print()

for p in ("baseline", "pipelined", "json-comp"):
    top(p)

anchors = [
    ("genhttp-ioxide", "baseline"),
    ("genhttp-ioxide", "pipelined"),
    ("genhttp-ioxide", "json-comp"),
    ("actix", "baseline"),
    ("bun", "json-comp"),
    ("rails", "baseline"),
]
print("  Named anchors on the board:")
for fw, prof in anchors:
    key = f"{prof}-4096"
    row = next((r for r in results[key] if r['fw'] == fw), None)
    if row:
        name = meta.get(fw, {}).get('display_name', fw)
        print(f"    {row['rps']:>12,.0f}  {name} ({prof})")
PY

log ""
log "==> how to read this"
log "- Same-box Go vs Orisha is the only apples-to-apples pair above."
log "- Board numbers use gcannon on Linux io_uring hardware; do not divide our wrk rps into their gcannon rps."
log "- Baseline board rotates GET + POST (CL + chunked); we only wrk GET baseline11."
log "- Pipelined board uses gcannon -p 16; wrk here sends one in-flight request per connection."
log "- json-comp board gzip-rotates /json/{25,40,50}; our json slice hits /json/10?m=1 without Accept-Encoding: gzip."
log ""
log "Results file: $OUT"
