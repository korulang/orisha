#!/usr/bin/env bash
# Nothing to a results table, on hardware anyone can rent for about a dollar.
#
#   ./run.sh            provision, build, verify, measure, report, destroy
#   ./run.sh --keep     leave the droplets up afterwards
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
KEEP=0; if [ "${1:-}" = "--keep" ]; then KEEP=1; shift; fi
SSH_KEY="${SSH_KEY:-$HOME/.ssh/koru_bench}"
SSH="ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i $SSH_KEY"
SCP="scp -o StrictHostKeyChecking=accept-new -i $SSH_KEY"

ORISHA_SRC="${ORISHA_SRC:-$HERE/../../examples/korulang-site}"
SITE_SRC="${SITE_SRC:-$HOME/src/korulang_org/build}"
STAGE="$HERE/.stage"
DUR="${DUR:-15s}"
ROUNDS="${ROUNDS:-3}"
WORKLOAD=("$@")
[ ${#WORKLOAD[@]} -eq 0 ] && WORKLOAD=("/index.html@200" "/index.html@50" "/200.html@200")

# ---------------------------------------------------------------------------
# 1. Artifacts, built here where the toolchain is
# ---------------------------------------------------------------------------
echo "==> building Orisha for x86_64 linux"
rm -rf "$STAGE"; mkdir -p "$STAGE"
( cd "$ORISHA_SRC" && koruc main.k build --build=linux    >/dev/null && cp a.out "$STAGE/orisha-epoll" )
( cd "$ORISHA_SRC" && koruc main.k build --build=io-uring >/dev/null && cp a.out "$STAGE/orisha-uring" )
file "$STAGE/orisha-epoll" | grep -q x86-64 || { echo "not an x86-64 binary — check the build target" >&2; exit 1; }

echo "==> staging the site with precompressed siblings"
cp -R "$SITE_SRC" "$STAGE/site"
( cd "$STAGE/site" && find . -type f \( -name '*.html' -o -name '*.css' -o -name '*.js' -o -name '*.json' -o -name '*.svg' -o -name '*.xml' -o -name '*.txt' \) -print0 \
	| xargs -0 -P 8 -I{} gzip -9 -k -f "{}" )
( cd "$STAGE" && tar czf site.tar.gz site && rm -rf site )

# ---------------------------------------------------------------------------
# 2. Machines
# ---------------------------------------------------------------------------
"$HERE/provision.sh"
# shellcheck disable=SC1090
. "$HERE/.hosts"

echo "==> shipping"
$SSH "root@$SERVER_PUB" 'mkdir -p /root/bench'
$SCP -q "$STAGE"/{orisha-epoll,orisha-uring,site.tar.gz} "root@$SERVER_PUB:/root/bench/"
$SCP -q "$HERE/server/setup.sh" "root@$SERVER_PUB:/root/bench/"
$SSH "root@$LOAD_PUB" 'mkdir -p /root/bench'
$SCP -q "$STAGE/site.tar.gz" "$HERE/load/measure.sh" "root@$LOAD_PUB:/root/bench/"

echo "==> preparing the load box"
$SSH "root@$LOAD_PUB" 'set -e; export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq && apt-get install -y -qq curl python3 >/dev/null
  # wrk is not in every Debian release; build it rather than silently skipping.
  if ! apt-get install -y -qq wrk >/dev/null 2>&1; then
    apt-get install -y -qq build-essential libssl-dev git >/dev/null
    git clone -q --depth 1 https://github.com/wg/wrk /tmp/wrk && make -s -C /tmp/wrk -j"$(nproc)" >/dev/null
    install /tmp/wrk/wrk /usr/local/bin/wrk
  fi
  wrk --version 2>&1 | head -1
  cd /root/bench && tar xzf site.tar.gz && chmod +x measure.sh'

echo "==> preparing the server box (this builds every contestant)"
$SSH "root@$SERVER_PUB" 'cd /root/bench && chmod +x setup.sh && ./setup.sh'

# ---------------------------------------------------------------------------
# 3. Provenance — recorded before any number is taken
# ---------------------------------------------------------------------------
STAMP="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
OUT="$HERE/results/$STAMP"; mkdir -p "$OUT"
{
	echo "region=$REGION size=$SIZE image=debian-13-x64"
	echo "server=$($SSH "root@$SERVER_PUB" 'uname -r; nproc; grep -m1 "model name" /proc/cpuinfo | cut -d: -f2-' | tr '\n' ' ')"
	echo "load=$($SSH "root@$LOAD_PUB" 'uname -r; nproc' | tr '\n' ' ')"
	echo "duration=$DUR rounds=$ROUNDS workload=${WORKLOAD[*]}"
	echo "--- excluded contestants ---"
	$SSH "root@$SERVER_PUB" 'cat /root/bench/excluded.txt 2>/dev/null' || true
} > "$OUT/provenance.txt"
cat "$OUT/provenance.txt"

# ---------------------------------------------------------------------------
# 4a. Correctness gate — once per contestant, before any timing exists.
# ---------------------------------------------------------------------------
declare -A PORTMAP=( [ols]=8088 )   # OpenLiteSpeed does not listen on 3000
ALL=(orisha-epoll orisha-uring nginx caddy sws h2o ols)

# seccomp=unconfined because Docker's default profile blocks io_uring_setup, and
# a blocked syscall is indistinguishable from a missing feature from inside. It
# is applied to EVERY contestant, not just ours, so nobody is sandboxed
# differently from anybody else.
up()   { $SSH "root@$SERVER_PUB" "docker rm -f live >/dev/null 2>&1; docker run -d --rm --name live --network host --security-opt seccomp=unconfined bench-$1 >/dev/null"; sleep 6; }
down() { $SSH "root@$SERVER_PUB" 'docker rm -f live >/dev/null 2>&1' || true; sleep 2; }
steal() { $SSH "root@$SERVER_PUB" "awk '/^cpu /{print \$9}' /proc/stat"; }

: > "$OUT/raw.txt"
RUNNERS=()
for c in "${ALL[@]}"; do
	$SSH "root@$SERVER_PUB" "docker image inspect bench-$c >/dev/null 2>&1" || { echo "  $c — no image, excluded"; continue; }
	port="${PORTMAP[$c]:-3000}"
	up "$c"
	set +e
	res="$($SSH "root@$LOAD_PUB" "cd /root/bench && ./measure.sh verify $SERVER_PRIV $c $port" 2>&1)"
	rc=$?
	set -e
	down
	echo "$res" | tee -a "$OUT/raw.txt" | sed 's/^/  /'
	if [ $rc -eq 0 ]; then RUNNERS+=("$c"); else echo "  $c — FAILED CORRECTNESS, will not be timed"; fi
done

echo "==> timing: ${RUNNERS[*]:-none}"
[ ${#RUNNERS[@]} -eq 0 ] && { echo "nothing passed correctness" >&2; "$HERE/teardown.sh"; exit 1; }

# ---------------------------------------------------------------------------
# 4b. The matrix. Interleaved, one contestant up at a time, steal sampled.
# ---------------------------------------------------------------------------
for r in $(seq 1 "$ROUNDS"); do
	for c in "${RUNNERS[@]}"; do
		port="${PORTMAP[$c]:-3000}"
		up "$c"
		s0="$(steal)"
		$SSH "root@$LOAD_PUB" "cd /root/bench && DUR=$DUR ./measure.sh time $SERVER_PRIV $c $port ${WORKLOAD[*]}" \
			| tee -a "$OUT/raw.txt" | sed 's/^/  /'
		s1="$(steal)"
		echo "STEAL|$c|round$r|$(( s1 - s0 ))" >> "$OUT/raw.txt"
		down
	done
done

# ---------------------------------------------------------------------------
# 5. Report
# ---------------------------------------------------------------------------
"$HERE/report.sh" "$OUT" | tee "$OUT/report.md"
echo "==> $OUT/report.md"

[ "$KEEP" = 1 ] || "$HERE/teardown.sh"
