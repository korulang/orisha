#!/usr/bin/env bash
# Does compiling the site against its own traffic buy anything?
#
# This is not a league table. nginx and H2O appear as CONTROLS, not rivals:
# neither can be given a profile, so both should score the same in every column,
# and if they do not, the machine moved and no other column means anything
# either. Two bars that cannot move next to two that might is the whole design.
#
# The two entries that can move are the same server compiled twice:
#
#   orisha-cold  — no profile. Routes in directory order.
#   orisha-warm  — compiled against an access log drawn from the traffic
#                  distribution, but NOT from the request sequence the benchmark
#                  replays. Same shape, independent sample. Compiling against the
#                  exact sequence would measure memorisation.
#
# The workload is Zipf-skewed across the whole site rather than one hot URL,
# because layout can only matter when requests spread over many responses. A
# single hot file lives in L2 for every contestant and settles nothing.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/koru_bench}"
SSH="ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i $SSH_KEY"
SCP="scp -o StrictHostKeyChecking=accept-new -i $SSH_KEY"
ORISHA_SRC="${ORISHA_SRC:-$HERE/../../examples/korulang-site}"
SITE_SRC="${SITE_SRC:-$HOME/src/korulang_org/build}"
STAGE="$HERE/.stage"; DUR="${DUR:-20s}"; ROUNDS="${ROUNDS:-3}"; ZIPF="${ZIPF:-1.1}"

echo "==> building the workload (zipf=$ZIPF, train and test drawn separately)"
rm -rf "$STAGE"; mkdir -p "$STAGE"
python3 "$HERE/workload.py" "$SITE_SRC" --train "$STAGE/orisha.profile" --test "$STAGE/test.lua" --zipf "$ZIPF"

echo "==> compiling Orisha twice from the same source"
( cd "$ORISHA_SRC" && rm -f orisha.profile
  koruc main.k build --build=linux >/dev/null 2>&1 && cp a.out "$STAGE/orisha-cold" )
( cd "$ORISHA_SRC" && cp "$STAGE/orisha.profile" orisha.profile
  koruc main.k build --build=linux 2>&1 | grep -E "STATIC_ROUTER..profile" || true
  cp a.out "$STAGE/orisha-warm"; rm -f orisha.profile )
cmp -s "$STAGE/orisha-cold" "$STAGE/orisha-warm" && { echo "the two builds are identical — ordering did nothing" >&2; exit 1; }
echo "    cold $(wc -c < "$STAGE/orisha-cold") bytes   warm $(wc -c < "$STAGE/orisha-warm") bytes"

cp -R "$SITE_SRC" "$STAGE/site"
( cd "$STAGE/site" && find . -type f \( -name '*.html' -o -name '*.css' -o -name '*.js' -o -name '*.json' -o -name '*.svg' -o -name '*.xml' -o -name '*.txt' \) -print0 \
	| xargs -0 -P 8 -I{} gzip -9 -k -f "{}" )
( cd "$STAGE" && tar czf site.tar.gz site && rm -rf site )

"$HERE/provision.sh"; . "$HERE/.hosts"

echo "==> shipping"
$SSH "root@$SERVER_PUB" 'mkdir -p /root/bench'
$SCP -q "$STAGE"/{orisha-cold,orisha-warm,site.tar.gz} "root@$SERVER_PUB:/root/bench/"
$SCP -q "$HERE/server/setup-profile.sh" "root@$SERVER_PUB:/root/bench/setup.sh"
$SSH "root@$LOAD_PUB" 'mkdir -p /root/bench'
$SCP -q "$STAGE/test.lua" "root@$LOAD_PUB:/root/bench/"
$SSH "root@$LOAD_PUB" 'export DEBIAN_FRONTEND=noninteractive; apt-get update -qq && apt-get install -y -qq wrk curl >/dev/null; wrk --version 2>&1|head -1'
$SSH "root@$SERVER_PUB" 'cd /root/bench && chmod +x setup.sh && ./setup.sh'

STAMP="$(date -u +%Y-%m-%dT%H-%M-%SZ)"; OUT="$HERE/results/profile-$STAMP"; mkdir -p "$OUT"
{ echo "zipf=$ZIPF duration=$DUR rounds=$ROUNDS"
  echo "server=$($SSH "root@$SERVER_PUB" 'uname -r; nproc; grep -m1 "model name" /proc/cpuinfo|cut -d: -f2-'|tr '\n' ' ')"
  echo "cold=$(wc -c < "$STAGE/orisha-cold") warm=$(wc -c < "$STAGE/orisha-warm")"
} > "$OUT/provenance.txt"; cat "$OUT/provenance.txt"

: > "$OUT/raw.txt"
for r in $(seq 1 "$ROUNDS"); do
	for c in orisha-cold orisha-warm nginx h2o; do
		$SSH "root@$SERVER_PUB" "docker rm -f live >/dev/null 2>&1; docker run -d --rm --name live --network host --security-opt seccomp=unconfined bench-$c >/dev/null"
		sleep 6
		line="$($SSH "root@$LOAD_PUB" "cd /root/bench && wrk -t8 -c200 -d$DUR -s test.lua --latency http://$SERVER_PRIV:3000 2>&1" \
			| awk -v c="$c" -v r="$r" '/Requests\/sec/{rps=$2} $1=="99%"{p99=$2} /Non-2xx/{n=$NF} END{printf "RESULT|%s|round%s|%s|%s|%s\n",c,r,rps,p99,(n==""?0:n)}')"
		echo "$line" | tee -a "$OUT/raw.txt"
		$SSH "root@$SERVER_PUB" 'docker rm -f live >/dev/null 2>&1' || true
		sleep 2
	done
done

python3 - "$OUT/raw.txt" <<'PY' | tee "$OUT/report.md"
import sys, collections, statistics as st
rows=collections.defaultdict(list)
for l in open(sys.argv[1]):
    p=l.strip().split('|')
    if p[0]=='RESULT' and p[3]: rows[p[1]].append(float(p[3]))
print("\n## Held-out skewed workload over the whole site\n")
print("| build | req/s (median) | vs cold |"); print("|---|---|---|")
base=st.median(rows.get('orisha-cold',[1]))
for k in ['orisha-cold','orisha-warm','nginx','h2o']:
    if k not in rows: continue
    m=st.median(rows[k])
    print(f"| {k} | {m:,.0f} | {m/base:.3f}x |")
# The failure this catches: if every contestant lands within a couple of percent
# of every other, the number is a property of the link, not of any server. A
# whole-site workload did exactly that at ~21,000 req/s — mean payload 49 KB
# against a 2 Gbit link — and would have been reported as "layout does nothing"
# by a run that never tested layout.
vals=[st.median(v) for v in rows.values() if v]
if vals and (max(vals)-min(vals))/max(vals) < 0.05:
    print("\n> **SUSPECT: every contestant landed within 5% of every other.**")
    print("> That is the signature of a shared bottleneck — almost always the")
    print("> network. Check mean payload against link capacity before reading")
    print("> anything into these numbers.\n")

print("\nnginx and h2o are controls — neither can read a profile, so any movement")
print("between their rounds is the machine, not the experiment.\n")
for k in rows: print(f"  {k}: {', '.join(f'{v:,.0f}' for v in rows[k])}")
PY
echo "==> $OUT/report.md"
"$HERE/teardown.sh"
