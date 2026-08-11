#!/usr/bin/env bash
# Runs ON the load droplet. Two modes, and the order between them is the point:
#
#   verify <ip> <name> <port>              prove it serves the right bytes
#   time   <ip> <name> <port> spec...      only then, time it
#
# A server that returns the wrong bytes scores nothing, not a high number. Ours
# once returned a 1.5 MB image at five different sizes on five consecutive
# requests and looked completely healthy doing it.
set -euo pipefail
cd /root/bench

MODE="$1"; TARGET="$2"; CONTESTANT="$3"; PORT="$4"; shift 4
BASE="http://$TARGET:$PORT"
DUR="${DUR:-15s}"

# What is actually on the wire — read off the response, never taken from a
# config file. Config says what was intended; the wire says what happened.
wire() {
	curl -s -D- -o /dev/null -H 'Accept-Encoding: gzip' "$BASE/index.html" \
		| tr -d '\r' | grep -iE '^(content-length|content-encoding)' | sort | tr '\n' ' '
}

# One curl process for the whole site: thousands of separate processes is
# minutes of overhead that says nothing about the server.
verify() {
	local out; out="$(mktemp -d)"
	mapfile -t files < <(cd site && find . -type f ! -name '*.gz' | sed 's|^\./||' | sort)
	local args=() i=0
	for f in "${files[@]}"; do
		args+=(-o "$out/$i" "$BASE/$(python3 -c 'import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))' "$f")")
		i=$((i+1))
	done
	curl -s --compressed --max-time 60 "${args[@]}" || true
	local ok=0 bad=0
	for i in "${!files[@]}"; do
		if cmp -s "$out/$i" "site/${files[$i]}"; then ok=$((ok+1)); else
			bad=$((bad+1)); [ $bad -le 5 ] && echo "    MISMATCH ${files[$i]} (want $(wc -c < "site/${files[$i]}"), got $(wc -c < "$out/$i" 2>/dev/null || echo 0))"
		fi
	done
	rm -rf "$out"
	echo "VERIFY|$CONTESTANT|$ok|$bad|${#files[@]}"
	[ "$bad" -eq 0 ]
}

case "$MODE" in
verify)
	echo "WIRE|$CONTESTANT|$(wire)"
	verify
	;;
time)
	for spec in "$@"; do
		P="${spec%%@*}"; C="${spec##*@}"
		T=$(( C < 100 ? 2 : 8 ))
		out=$(wrk -t$T -c"$C" -d"$DUR" -H 'Accept-Encoding: gzip' --latency "$BASE$P" 2>&1)
		rps=$(echo "$out" | awk '/Requests\/sec/{print $2}')
		p50=$(echo "$out" | awk '$1=="50%"{print $2}')
		p99=$(echo "$out" | awk '$1=="99%"{print $2}')
		non2=$(echo "$out" | awk '/Non-2xx/{print $NF}')
		echo "RESULT|$CONTESTANT|$P|$C|${rps:-0}|${p50:-?}|${p99:-?}|${non2:-0}"
	done
	;;
*) echo "unknown mode: $MODE" >&2; exit 64 ;;
esac
