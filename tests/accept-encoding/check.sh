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

# HEAD: headers of the negotiated variant, and ZERO bytes after the head
# terminator on the wire (curl -I would hide a leaked body — inspect raw).
head_wire() {
    local path="$1" ae="$2"
    local ae_hdr=""
    [ "$ae" != "NONE" ] && ae_hdr="Accept-Encoding: ${ae}\r\n"
    printf "HEAD %s HTTP/1.1\r\nHost: x\r\n%bConnection: close\r\n\r\n" "$path" "$ae_hdr" \
        | nc -w 3 localhost "$PORT"
}
head_check() {
    local desc="$1" url_path="$2" ae="$3" want_ce="$4"
    head_wire "$url_path" "$ae" > /tmp/ae_head.bin
    if python3 - "$want_ce" /tmp/ae_head.bin <<'PY'
import sys
want_ce, path = sys.argv[1] == "1", sys.argv[2]
d = open(path, 'rb').read()
i = d.find(b"\r\n\r\n")
if i < 0 or len(d) != i + 4:
    print(f"FAIL head not terminal: {len(d)} bytes, terminator at {i}", file=sys.stderr)
    sys.exit(1)
has_ce = b"content-encoding: gzip" in d[:i].lower()
sys.exit(0 if has_ce == want_ce else 1)
PY
    then printf 'ok   %s\n' "$desc"; else printf 'FAIL %s\n' "$desc"; fail=1; fi
}
head_check "HEAD no AE -> identity head only"    "/index.html" NONE   0
head_check "HEAD AE:gzip -> gzip head only"      "/index.html" "gzip" 1
head_check "HEAD AE:gzip;q=0 -> identity head"   "/index.html" "gzip;q=0" 0
head_check "HEAD fallback AE:gzip -> gzip head"  "/no/such/path" "gzip" 1

# Strong etags are per-representation: identity and gzip MUST differ, and
# If-None-Match validates the selected variant only.
etag_id="$(curl -s -D- -o /dev/null "$BASE/index.html" | grep -i '^etag:' | tr -d '\r' | awk '{print $2}')"
etag_gz="$(curl -s -D- -o /dev/null -H 'Accept-Encoding: gzip' "$BASE/index.html" | grep -i '^etag:' | tr -d '\r' | awk '{print $2}')"
if [ -n "$etag_id" ] && [ -n "$etag_gz" ] && [ "$etag_id" != "$etag_gz" ]; then
    echo "ok   distinct strong etags ($etag_id vs $etag_gz)"
else
    echo "FAIL etags identical or missing: id=$etag_id gz=$etag_gz"; fail=1
fi
code=$(curl -s -o /dev/null -w '%{http_code}' -H "If-None-Match: $etag_gz" -H 'Accept-Encoding: gzip' "$BASE/index.html")
[ "$code" = "304" ] && echo "ok   gzip etag + AE:gzip -> 304" || { echo "FAIL gzip etag revalidate: $code"; fail=1; }
code=$(curl -s -o /dev/null -w '%{http_code}' -H "If-None-Match: $etag_id" "$BASE/index.html")
[ "$code" = "304" ] && echo "ok   identity etag + no AE -> 304" || { echo "FAIL identity etag revalidate: $code"; fail=1; }
code=$(curl -s -o /dev/null -w '%{http_code}' -H "If-None-Match: $etag_id" -H 'Accept-Encoding: gzip' "$BASE/index.html")
[ "$code" = "200" ] && echo "ok   identity etag + AE:gzip -> 200 (wrong variant)" || { echo "FAIL cross-variant match: $code"; fail=1; }

# Dynamic route is untouched by negotiation.
body="$(curl -s "$BASE/api/health")"
if [ "$body" = '{"status":"ok"}' ]; then
    echo "ok   dynamic route untouched"
else
    echo "FAIL dynamic route: $body"; fail=1
fi

exit $fail
