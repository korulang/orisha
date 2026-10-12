#!/usr/bin/env bash
# bench-httparena.sh — HttpArena-shaped workloads on the two-box rig.
#
# The single-box HttpArena harness shares every core between the server and
# the load generator when the profile cpuset doesn't fit (on a c-4 it never
# fits: profiles want 0-31,64-95). Numbers from that are ratios, not
# throughput — the same failure this whole directory exists to prevent.
#
# Here the server gets one machine, gcannon gets the other, private link
# between them. Identical invocations to scripts/lib (conns, threads,
# duration, pipeline, req_per_conn, raw templates) — only the court changes.
#
#   ./bench-httparena.sh [framework...]     provision, build, gate, measure
#   ./bench-httparena.sh --keep             leave the pair up afterwards
#   PROFILES="baseline,pipelined,limited-conn,json-comp" ./bench-httparena.sh
#   PROFILES="json-tls" ./bench-httparena.sh          # wrk over :8081, not gcannon
#
# json-tls swaps the generator for wrk (same invocation as
# scripts/lib/tools/wrk.sh: -t 64 -c 4096 -d 5s + json-tls-rotate.lua against
# https://:8081) and additionally samples /proc/net/tls_stat mid-run — whether
# the kernel's TLS record layer owns the conn is the difference between
# "TLS is our serializer's overhead" and "TLS is a separate wall".
#
# The court refuses to run dirty: before any timing it proves
#   - exactly ONE process owns the bench port's listeners (SO_REUSEPORT
#     shares a pid; a second container/process is contamination)
#   - the running binary's sha256 is stamped — not the image tag's promise
#   - the server answers a real gzipped request over the private link
#   - server and load are distinct machines
# Every check's output lands in provenance.txt next to the numbers, so the
# run falsifies itself if anything was wrong.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
KEEP=0
[ "${1:-}" = "--keep" ] && { KEEP=1; shift; }
SSH_KEY="${SSH_KEY:-$HOME/.ssh/koru_bench}"
SSH="ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i $SSH_KEY"
SCP="scp -o StrictHostKeyChecking=accept-new -i $SSH_KEY"

HA_REPO="${HA_REPO:-$HOME/src/HttpArena}"
FRAMEWORKS=("$@"); [ ${#FRAMEWORKS[@]} -eq 0 ] && FRAMEWORKS=(orisha orisha-uring zix)
PROFILES="${PROFILES:-baseline,pipelined,limited-conn,json-comp}"
ROUNDS="${ROUNDS:-3}"
DUR="${DUR:-5s}"
THREADS="${THREADS:-64}"
PORT=8080
REQ_DIR=/root/bench/requests

fail() { echo "!! $*" >&2; exit 1; }
say()  { echo "==> $*"; }

# ── Profile → gcannon arguments (verbatim from HttpArena scripts/lib) ────────
# spec: endpoint|conns|pipeline|req_per_conn
profile_spec() {
	case "$1" in
	baseline)     echo "|4096|1|0" ;;
	pipelined)    echo "pipeline|4096|16|0" ;;
	limited-conn) echo "|4096|1|10" ;;
	json-comp)    echo "json-compressed|4096,16384|1|25" ;;
	json-tls)     echo "json-tls|4096|1|0" ;;
	*) fail "unknown profile '$1'" ;;
	esac
}
gcannon_args() { # endpoint conns pipeline rpc -> arg string
	local ep="$1" conns="$2" pipe="$3" rpc="$4"
	case "$ep" in
	"")
		printf 'http://%s:%s --raw %s/get.raw,%s/post_cl.raw,%s/post_chunked.raw -c %s -t %s -d %s -p %s' \
			"$SERVER_PRIV" "$PORT" "$REQ_DIR" "$REQ_DIR" "$REQ_DIR" "$conns" "$THREADS" "$DUR" "$pipe"
		if [ "$rpc" -gt 0 ]; then printf ' -r %s' "$rpc"; fi ;;
	pipeline)
		printf 'http://%s:%s/pipeline -c %s -t %s -d %s -p %s' \
			"$SERVER_PRIV" "$PORT" "$conns" "$THREADS" "$DUR" "$pipe" ;;
	json-compressed)
		printf 'http://%s:%s --raw %s/json-gzip-25.raw,%s/json-gzip-40.raw,%s/json-gzip-50.raw -c %s -t %s -d %s -p %s -r %s' \
			"$SERVER_PRIV" "$PORT" "$REQ_DIR" "$REQ_DIR" "$REQ_DIR" "$conns" "$THREADS" "$DUR" "$pipe" "$rpc" ;;
	esac
}

# ── 1. Machines ─────────────────────────────────────────────────────────────
"$HERE/provision.sh"
# shellcheck disable=SC1091
. "$HERE/.hosts"
[ "$SERVER_PRIV" != "$LOAD_PRIV" ] || fail "server and load are the same machine — no court"

STAMP="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
OUT="$HERE/results/ha-$STAMP"; mkdir -p "$OUT"
STAGE="$(mktemp -d /tmp/ha-stage.XXXXXX)"; trap 'rm -rf "$STAGE"' EXIT

# ── 2. Stage the harness: Dockerfiles+requests go to their respective boxes ──
say "staging HttpArena @ $(cd "$HA_REPO" && git rev-parse --short HEAD)"
( cd "$HA_REPO" && git archive -o "$STAGE/ha.tar" HEAD 2>/dev/null \
	|| tar cf "$STAGE/ha.tar" --exclude='.git' --exclude='data' . )
# Local-only entry dirs (untracked or ahead of upstream) ride along on top.
( cd "$HA_REPO" && tar rf "$STAGE/ha.tar" frameworks/orisha frameworks/orisha-uring 2>/dev/null ) || true
$SSH "root@$SERVER_PUB" 'mkdir -p /root/bench/ha'
$SSH "root@$LOAD_PUB"   'mkdir -p /root/bench/ha /root/bench/requests'
# On a reused pair the tar is usually byte-identical — a remote size+sha
# match skips the 279MB transatlantic push entirely.
LOCAL_SHA="$(shasum -a 256 "$STAGE/ha.tar" | awk '{print $1}')"
for ip in "$SERVER_PUB" "$LOAD_PUB"; do
	remote_sha="$($SSH "root@$ip" 'sha256sum /root/bench/ha.tar 2>/dev/null | cut -d" " -f1')"
	if [ "$remote_sha" != "$LOCAL_SHA" ]; then
		$SCP -q "$STAGE/ha.tar" "root@$ip:/root/bench/ha.tar"
	fi
done
$SSH "root@$SERVER_PUB" 'cd /root/bench/ha && tar xf /root/bench/ha.tar'
$SSH "root@$LOAD_PUB"   'cd /root/bench/ha && tar xf /root/bench/ha.tar && cp requests/*.raw requests/*.lua /root/bench/requests/'

# ── 3. Build: framework images on the server box, gcannon on the load box ────
say "building gcannon on the load box"
$SSH "root@$LOAD_PUB" 'set -e
  command -v docker >/dev/null || { apt-get update -qq && apt-get install -y -qq docker.io >/dev/null; }
  cd /root/bench/ha && docker build -q -t gcannon:latest -f docker/gcannon.Dockerfile docker \
    --build-arg CACHE_BUST='"$(date +%s)"' >/dev/null && docker image inspect gcannon:latest -f "{{.Id}}"'

if [[ ",$PROFILES," == *",json-tls,"* ]]; then
	say "building wrk on the load box (json-tls generator)"
	$SSH "root@$LOAD_PUB" 'set -e
	  cd /root/bench/ha && docker build -q -t wrk:local -f docker/wrk.Dockerfile docker >/dev/null \
	    && docker image inspect wrk:local -f "{{.Id}}"'
fi
$SSH "root@$LOAD_PUB" 'apt-get install -y -qq curl python3 >/dev/null 2>&1 || true'
if [[ ",$PROFILES," == *",json-tls,"* ]]; then
	$SSH "root@$SERVER_PUB" 'apt-get install -y -qq linux-perf >/dev/null 2>&1 || apt-get install -y -qq perf >/dev/null 2>&1; command -v perf || ls /usr/bin/perf_* 2>/dev/null | head -1' >/dev/null 2>&1 || true
fi

say "building framework images on the server box"
for fw in "${FRAMEWORKS[@]}"; do
	$SSH "root@$SERVER_PUB" "test -f /root/bench/ha/frameworks/$fw/Dockerfile" \
		|| fail "no frameworks/$fw/Dockerfile staged"
	$SSH "root@$SERVER_PUB" 'set -e
	  command -v docker >/dev/null || { apt-get update -qq && apt-get install -y -qq docker.io >/dev/null; }
	  cd /root/bench/ha && docker build -q -t '"httparena-$fw"' -f '"frameworks/$fw/Dockerfile"' '"frameworks/$fw"' >/dev/null \
	    && echo "  built httparena-'"$fw"' $(docker image inspect httparena-'"$fw"' -f "{{.Id}}")"'
done

# ── 4. The court gate ────────────────────────────────────────────────────────
up()   { $SSH "root@$SERVER_PUB" "docker rm -f live >/dev/null 2>&1 || true; \
  docker run -d --rm --name live --network host --security-opt seccomp=unconfined \
    --ulimit memlock=-1:-1 --ulimit nofile=1048576:1048576 \
    -v /root/bench/ha/data/dataset.json:/data/dataset.json:ro \
    -v /root/bench/ha/data/static:/data/static:ro \
    -v /root/bench/ha/certs:/certs:ro \
    httparena-$1 >/dev/null"; }
down() { $SSH "root@$SERVER_PUB" 'docker rm -f live >/dev/null 2>&1' || true; sleep 1; }

# ── kTLS feasibility probe — once, before timing ─────────────────────────────
# The board court answered "is kTLS live" only indirectly; here we ask the
# kernel directly. modprobe succeeds iff the host's module dir ships tls.ko —
# if it loads and TlsCurrTxSw still reads zero during a run, the install path
# itself is what never engages.
if [[ ",$PROFILES," == *",json-tls,"* ]]; then
	say "kTLS probe on the server box"
	$SSH "root@$SERVER_PUB" 'modprobe tls 2>&1; echo "modprobe_rc=$?"; ls /proc/net/tls_stat 2>/dev/null || echo "tls_stat absent after modprobe"; lsmod | grep -i "^tls" || true' \
		| tee "$OUT/ktls-probe.txt"
fi

court_check() { # framework -> refuses (exit 1) unless the court is clean
	local fw="$1" i
	for i in $(seq 1 30); do
		$SSH "root@$SERVER_PUB" "ss -tln 'sport = :$PORT' | grep -q LISTEN" && break
		[ "$i" = 30 ] && { echo "GATE|$fw|FAIL no listener on :$PORT after 15s"; return 1; }
		sleep 0.5
	done
	# one owner pid across every :8080 socket — REUSEPORT shares a pid,
	# a second process/container is contamination
	local pids
	pids="$($SSH "root@$SERVER_PUB" "ss -tlnp 'sport = :$PORT' | grep -oP 'pid=\K[0-9]+' | sort -u")"
	[ "$(echo "$pids" | grep -c .)" = 1 ] \
		|| { echo "GATE|$fw|FAIL port owned by pids: $(echo "$pids" | tr '\n' ' ')"; return 1; }
	local pid="$pids" cpid
	cpid="$($SSH "root@$SERVER_PUB" 'docker inspect live -f {{.State.Pid}}')"
	[ "$pid" = "$cpid" ] \
		|| { echo "GATE|$fw|FAIL port pid $pid is not the live container pid $cpid"; return 1; }
	# no containers besides live — a stale server holding REUSEPORT would
	# silently split every run's traffic (measured, twice)
	local others
	others="$($SSH "root@$SERVER_PUB" 'docker ps --format {{.Names}}' | grep -cvx live || true)"
	[ "$others" = 0 ] || { echo "GATE|$fw|FAIL other containers running"; return 1; }
	# the running binary, hashed — what is measured, not what was intended
	local sha
	sha="$($SSH "root@$SERVER_PUB" "sha256sum /proc/$pid/exe | cut -d' ' -f1")"
	echo "GATE|$fw|pid=$pid|binsha=$sha"
	# workload-appropriate correctness: a real gzipped response that inflates
	$SSH "root@$LOAD_PUB" "curl -sf --max-time 10 -H 'Accept-Encoding: gzip' \
	  'http://$SERVER_PRIV:$PORT/json/25?m=4' | gzip -dc | python3 -c 'import json,sys; json.load(sys.stdin)'" \
		|| { echo "GATE|$fw|FAIL /json/25?m=4 did not return inflating JSON"; return 1; }
	echo "GATE|$fw|correctness=200+gzip+json over $SERVER_PRIV"
	if [[ ",$PROFILES," == *",json-tls,"* ]]; then
		# the TLS port is part of the measured surface — same owner, same pid
		local tpids
		tpids="$($SSH "root@$SERVER_PUB" "ss -tlnp 'sport = :8081' | grep -oP 'pid=\K[0-9]+' | sort -u")"
		[ "$tpids" = "$pid" ] \
			|| { echo "GATE|$fw|FAIL :8081 owned by pids: $(echo "$tpids" | tr '\n' ' ')"; return 1; }
		local tready=0 ti
		for ti in $(seq 1 8); do
			if $SSH "root@$LOAD_PUB" "curl -skf --max-time 10 \
			  --resolve 'bench.localhost:8081:$SERVER_PRIV' \
			  'https://bench.localhost:8081/json/25?m=4' | python3 -c 'import json,sys; json.load(sys.stdin)'" 2>/dev/null; then
				tready=1; break
			fi
			sleep 1.5
		done
		if [ "$tready" != 1 ]; then
			$SSH "root@$LOAD_PUB" "curl -skv --max-time 10 \
			  --resolve 'bench.localhost:8081:$SERVER_PRIV' \
			  'https://bench.localhost:8081/json/25?m=4' -o /dev/null 2>&1 | tail -15" \
				2>/dev/null | sed "s/^/GATE|$fw|curl|/"
			$SSH "root@$SERVER_PUB" 'docker logs --tail 15 live 2>&1' \
				| sed "s/^/GATE|$fw|logs|/"
			echo "GATE|$fw|FAIL https /json/25?m=4 not valid JSON after 8 tries"
			return 1
		fi
		echo "GATE|$fw|tls=8081 same pid, https+200+json verified"
	fi
	return 0
}

steal()   { $SSH "root@$1" "awk '/^cpu /{print \$9}' /proc/stat"; }
cpustat() { $SSH "root@$1" "awk '/^cpu /{print \$2+\$3+\$4+\$6+\$7+\$8, \$2+\$3+\$4+\$5+\$6+\$7+\$8}' /proc/stat"; }
busy_pct() { awk -v a="$1" -v t="$2" -v A="$3" -v T="$4" 'BEGIN{printf "%d", (T>t)?100*(A-a)/(T-t):0}'; }

# ── 5. Provenance — before any number exists ─────────────────────────────────
{
	echo "stamp=$STAMP region=$REGION size=$SIZE profiles=$PROFILES rounds=$ROUNDS dur=$DUR threads=$THREADS"
	echo "server=$($SSH "root@$SERVER_PUB" 'uname -r; nproc; grep -m1 "model name" /proc/cpuinfo | cut -d: -f2-; cat /etc/machine-id' | tr '\n' ' ')"
	echo "load  =$($SSH "root@$LOAD_PUB" 'uname -r; nproc; grep -m1 "model name" /proc/cpuinfo | cut -d: -f2-; cat /etc/machine-id' | tr '\n' ' ')"
	echo "frameworks=${FRAMEWORKS[*]}"
	for fw in "${FRAMEWORKS[@]}"; do
		echo "image httparena-$fw: $($SSH "root@$SERVER_PUB" "docker image inspect httparena-$fw -f '{{.Id}}'")"
	done
	echo "image gcannon: $($SSH "root@$LOAD_PUB" "docker image inspect gcannon:latest -f '{{.Id}}'")"
	echo "remote-refs: orisha=$(git ls-remote https://github.com/korulang/orisha HEAD | cut -c1-12) koru=$(git ls-remote https://github.com/korulang/koru HEAD | cut -c1-12)"
} > "$OUT/provenance.txt"
cat "$OUT/provenance.txt"

: > "$OUT/raw.txt"

# ── 6. Gate every framework once, then interleaved timing ────────────────────
RUNNERS=()
for fw in "${FRAMEWORKS[@]}"; do
	up "$fw"
	if court_check "$fw" | tee -a "$OUT/raw.txt"; then RUNNERS+=("$fw"); fi
	down
done
[ ${#RUNNERS[@]} -gt 0 ] || fail "no framework passed the court gate"
say "timing: ${RUNNERS[*]}"

parse_rps() { sed -n 's/.*2xx=\([0-9][0-9]*\).*/\1/p' <<<"$1" | head -1; }
parse_dur() { sed -n 's/.*requests in \([0-9.]*\).*/\1/p' <<<"$1" | head -1; }
# wrk: "Requests/sec:  36323.61" — and "Socket errors: connect 0, read 0,
# write 0, timeout 0" plus optional "Non-2xx or 3xx responses: N"
parse_wrk_rps() { sed -n 's/ *Requests\/sec: *\([0-9.]*\).*/\1/p' <<<"$1" | head -1; }
parse_wrk_errs() {
	sed -n 's/.*Socket errors: connect \([0-9]*\), read \([0-9]*\), write \([0-9]*\), timeout \([0-9]*\).*/\1 \2 \3 \4/p' \
		<<<"$1" | awk '{s=0; for(i=1;i<=NF;i++) s+=$i; print s}'
}

IFS=',' read -ra PROF_ARR <<<"$PROFILES"
for p in "${PROF_ARR[@]}"; do
	spec="$(profile_spec "$p")"; IFS='|' read -r ep conns_list pipe rpc <<<"$spec"
	IFS=',' read -ra CONNS_ARR <<<"$conns_list"
	for r in $(seq 1 "$ROUNDS"); do
		for conns in "${CONNS_ARR[@]}"; do
			for fw in "${RUNNERS[@]}"; do
				up "$fw"; sleep 4
				s0=$(steal "$SERVER_PUB"); s_stat=($(cpustat "$SERVER_PUB")); l_stat=($(cpustat "$LOAD_PUB"))
				if [ "$ep" = "json-tls" ]; then
					# mid-run kTLS census: does the kernel own the record layer,
					# or is every byte still paying the mem-BIO toll?
					ktlsfile="$OUT/tlsstat-$fw-r$r.txt"
					( $SSH "root@$SERVER_PUB" 'sleep 3; cat /proc/net/tls_stat 2>/dev/null || echo NO_TLS_STAT' >"$ktlsfile" ) &
					( $SSH "root@$SERVER_PUB" 'PERF=$(command -v perf || ls /usr/bin/perf_* 2>/dev/null | head -1); [ -n "$PERF" ] || { echo NO_PERF; exit 0; }; sleep 1; pid=$(docker inspect live -f "{{.State.Pid}}"); "$PERF" record -F 199 -g -p "$pid" -o /tmp/perf.$$ -- sleep 3 >/dev/null 2>&1 && "$PERF" report -i /tmp/perf.$$ --stdio 2>/dev/null | head -45; rm -f /tmp/perf.$$' >"$OUT/perf-$fw-r$r.txt" ) &
					out="$($SSH "root@$LOAD_PUB" "timeout 90 docker run --rm --network host \
					  --ulimit nofile=1048576:1048576 \
					  --add-host bench.localhost:$SERVER_PRIV \
					  -v $REQ_DIR:$REQ_DIR:ro \
					  wrk:local -t $THREADS -c $conns -d $DUR \
					  -s $REQ_DIR/json-tls-rotate.lua https://bench.localhost:8081" 2>&1)"
					wait
					rps="$(parse_wrk_rps "$out")"; rps="${rps%%.*}"
					ok=$(sed -n 's/.* \([0-9][0-9]*\) requests in .*/\1/p' <<<"$out" | head -1)
					sockerrs="$(parse_wrk_errs "$out")"
					non2xx=$(sed -n 's/.*Non-2xx or 3xx responses: \([0-9]*\).*/\1/p' <<<"$out" | head -1)
					errs=$(( ${sockerrs:-0} + ${non2xx:-0} ))
					ktls=$(awk '/TlsCurrTxSw/{print $NF}' "$ktlsfile" 2>/dev/null | head -1)
					s1=$(steal "$SERVER_PUB"); s_stat2=($(cpustat "$SERVER_PUB")); l_stat2=($(cpustat "$LOAD_PUB"))
					scpu=$(busy_pct "${s_stat[@]}" "${s_stat2[@]}"); lcpu=$(busy_pct "${l_stat[@]}" "${l_stat2[@]}")
					flag=""; [ "${lcpu:-0}" -gt 92 ] && flag="LOADBOUND"
					echo "RESULT|$fw|$p|c$conns|r$r|rps=${rps:-0}|2xx=${ok:-0}|errs=$errs|servercpu=${scpu:-?}|loadcpu=${lcpu:-?}|steal=$((s1-s0))|ktls_tx=${ktls:-none}${flag:+|$flag}" \
						| tee -a "$OUT/raw.txt"
					echo "$out" >> "$OUT/wrk-$fw-$p-c$conns-r$r.log"
				else
					args="$(gcannon_args "$ep" "$conns" "$pipe" "$rpc")"
					out="$($SSH "root@$LOAD_PUB" "timeout 90 docker run --rm --network host --security-opt seccomp=unconfined \
					  --ulimit memlock=-1:-1 --ulimit nofile=1048576:1048576 \
					  -v $REQ_DIR:$REQ_DIR:ro \
					  gcannon:latest $args" 2>&1)"
					s1=$(steal "$SERVER_PUB"); s_stat2=($(cpustat "$SERVER_PUB")); l_stat2=($(cpustat "$LOAD_PUB"))
					scpu=$(busy_pct "${s_stat[@]}" "${s_stat2[@]}"); lcpu=$(busy_pct "${l_stat[@]}" "${l_stat2[@]}")
					ok=$(parse_rps "$out"); dur_s=$(parse_dur "$out")
					rps="$(awk -v ok="${ok:-0}" -v d="${dur_s:-1}" 'BEGIN{printf "%d", ok/d}')"
					err4=$(sed -n 's/.*4xx=\([0-9][0-9]*\).*/\1/p' <<<"$out" | head -1)
					err5=$(sed -n 's/.*5xx=\([0-9][0-9]*\).*/\1/p' <<<"$out" | head -1)
					errs=$(( ${err4:-0} + ${err5:-0} ))
					flag=""; [ "${lcpu:-0}" -gt 92 ] && flag="LOADBOUND"
					echo "RESULT|$fw|$p|c$conns|r$r|rps=$rps|2xx=${ok:-0}|errs=$errs|servercpu=${scpu:-?}|loadcpu=${lcpu:-?}|steal=$((s1-s0))${flag:+|$flag}" \
						| tee -a "$OUT/raw.txt"
					echo "$out" >> "$OUT/gcannon-$fw-$p-c$conns-r$r.log"
				fi
				down
			done
		done
	done
done

# ── 7. Report: medians, spreads, flags — no verdict without a clean court ────
{
	echo "# HttpArena two-box — $STAMP"
	echo
	echo '```'; cat "$OUT/provenance.txt"; echo '```'
	echo
	echo "| framework | profile | conns | median rps | spread (min-max) | notes |"
	echo "|---|---|---:|---:|---:|---|"
	awk -F'|' '/^RESULT\|/{k=$2"|"$3"|"$4; sub(/rps=/,"",$6); n[k]++; v[k,n[k]]=$6+0;
		if ($0 ~ /errs=[1-9]/ || $0 ~ /LOADBOUND/) f[k]=1}
	END{for(k in n){c=int((n[k]+1)/2); lo=v[k,1]; hi=v[k,1];
		for(i=1;i<=n[k];i++){if(v[k,i]<lo)lo=v[k,i]; if(v[k,i]>hi)hi=v[k,i]}
		split(k,kk,"|"); printf "| %s | %s | %s | %d | %d-%d | %s |\n",
			kk[1],kk[2],kk[3], v[k,c], lo, hi, (f[k]?"flagged":"")}}' \
		"$OUT/raw.txt" | sort -t'|' -k3,3 -k4,4n
} | tee "$OUT/report.md"

say "$OUT/report.md"
[ "$KEEP" = 1 ] || "$HERE/teardown.sh"
