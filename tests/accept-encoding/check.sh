#!/usr/bin/env bash
# Accept-Encoding negotiation probe — wire assertions against a live server.
#
#   koruc main.k && ./check.sh
#
# Asserts, per RFC 9110 §12.5.3:
#   - gzip leaves only when advertised (bare, listed, or via `*`)
#   - `q=0` on gzip — or on `*` with no explicit gzip — serves identity
#   - an explicit gzip entry decides over the wildcard either way
#   - Vary: Accept-Encoding rides BOTH variants of a negotiated route
#   - the SPA fallback negotiates identically
set -euo pipefail
cd "$(dirname "$0")"

PORT=3101
BASE="http://localhost:$PORT"

./a.out & SERVER_PID=$!
trap 'kill $SERVER_PID 2>/dev/null || true' EXIT
sleep 1

fail=0
check() {
    local desc="$1" url="$2" ae="$3" want_encoding="$4" want_vary="$5"
    local args=(-s -D- -o /dev/null)
    if [ "$ae" != "NONE" ]; then args+=(-H "Accept-Encoding: $ae"); fi
    local head
    head="$(curl "${args[@]}" "$url")"
    local has_ce has_vary
    has_ce=$(printf '%s' "$head" | grep -ci 'content-encoding: gzip' || true)
    has_vary=$(printf '%s' "$head" | grep -ci 'vary:.*accept-encoding' || true)
    if [ "$has_ce" = "$want_encoding" ] && [ "$has_vary" = "$want_vary" ]; then
        printf 'ok   %-42s ce=%s vary=%s\n' "$desc" "$has_ce" "$has_vary"
    else
        printf 'FAIL %-42s ce=%s (want %s) vary=%s (want %s)\n' "$desc" "$has_ce" "$want_encoding" "$has_vary" "$want_vary"
        printf '%s\n' "$head" | grep -i 'content-encoding\|vary\|content-length' || true
        fail=1
    fi
}

#                    description                              url                    AE                want_ce want_vary
check "no header -> identity"              "$BASE/index.html"  NONE                  0 1
check "gzip -> gzip"                       "$BASE/index.html"  "gzip"                1 1
check "br (gzip absent) -> identity"       "$BASE/index.html"  "br"                  0 1
check "gzip;q=0 refused -> identity"       "$BASE/index.html"  "gzip;q=0"            0 1
check "gzip;q=0.000 refused -> identity"   "$BASE/index.html"  "gzip;q=0.000"        0 1
check "gzip;q=0.5 -> gzip"                 "$BASE/index.html"  "gzip;q=0.5"          1 1
check "gzip ; q=0 -> identity"             "$BASE/index.html"  "gzip ; q=0"          0 1
check "* -> gzip"                          "$BASE/index.html"  "*"                   1 1
check "br, * -> gzip"                      "$BASE/index.html"  "br, *"               1 1
check "*;q=0 -> identity"                  "$BASE/index.html"  "*;q=0"               0 1
check "gzip;q=0, * -> identity"            "$BASE/index.html"  "gzip;q=0, *"         0 1
check "*;q=0, gzip -> gzip"                "$BASE/index.html"  "*;q=0, gzip"         1 1
check "deflate, gzip, br -> gzip"          "$BASE/index.html"  "deflate, gzip, br"   1 1

# Fallback negotiates the same way.
check "fallback gzip;q=0 -> identity"      "$BASE/no/such/path" "gzip;q=0"           0 1
check "fallback gzip -> gzip"              "$BASE/no/such/path" "gzip"               1 1

# Dynamic route is untouched by negotiation.
body="$(curl -s "$BASE/api/health")"
if [ "$body" = '{"status":"ok"}' ]; then
    echo "ok   dynamic route untouched"
else
    echo "FAIL dynamic route: $body"; fail=1
fi

exit $fail
