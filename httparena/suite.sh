#!/usr/bin/env bash
# HttpArena accommodation checklist — correctness first, then builds, then smoke.
#
#   ./suite.sh              full local checklist
#   ./suite.sh validate     only validate.sh (needs HttpArena checkout)
#   ./suite.sh build        cold + warm board-mix builds
#   ./suite.sh smoke        bench.sh pipeline
#
# Env:
#   HTTPARENA_ROOT  path to HttpArena repo (default: ../../HttpArena)
set -euo pipefail

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:${PATH:-}"

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
HTTPARENA_ROOT="${HTTPARENA_ROOT:-$HERE/../../HttpArena}"
BASH5="${BASH5:-/opt/homebrew/bin/bash}"
mkdir -p results profiles/generated

step() { printf '\n==> %s\n' "$*"; }

check_meta_profiles() {
    step "meta.json scored profiles (must implement + validate)"
    python3 - <<PY
import json
meta = json.load(open("$HTTPARENA_ROOT/frameworks/orisha/meta.json"))
tests = meta.get("tests", [])
print("  subscribed:", ", ".join(tests))
expected = [
    "baseline", "latency-1m", "latency-10k", "pipelined",
    "limited-conn", "json-comp", "json-tls",
]
missing = [t for t in expected if t not in tests]
extra = [t for t in tests if t not in expected]
if missing:
    print("  MISSING from meta:", missing)
if extra:
    print("  extra:", extra)
print("  routes: /baseline11  /pipeline  /json/{count}?m=")
PY
}

run_validate() {
    step "validate.sh orisha (local tree via Docker)"
    if ! docker info >/dev/null 2>&1; then
        echo "  fail: Docker daemon not running — start Docker Desktop" >&2
        return 1
    fi
    if [ ! -x "$BASH5" ]; then
        echo "  fail: bash 5+ required (brew install bash) — profiles.sh uses declare -A" >&2
        return 1
    fi
    "$HERE/validate-local.sh"
}

run_builds() {
    step "PGO build matrix (cold vs warm board-mix)"
    ./build.sh cold
    ./build.sh warm board-mix
    step "profile-specific warm builds (compile-only)"
    for p in baseline json-comp pipelined latency; do
        ./build.sh warm "$p"
    done
}

run_smoke() {
    step "wrk smoke (not evidence — see DISCIPLINE.md)"
    DURATION=5s CONNECTIONS=50 ./bench.sh pipeline
}

run_pgo_showcase() {
    step "PGO showcase — cold vs warm must differ when router/static PGO applies"
    ./build.sh cold
    cp a.out results/orisha-cold-a.out
    ./build.sh warm board-mix
    cp a.out results/orisha-warm-a.out
    if cmp -s results/orisha-cold-a.out results/orisha-warm-a.out; then
        echo "  fail: cold and warm binaries identical — router PGO should reorder branches" >&2
        return 1
    fi
    echo "  warm and cold binaries differ (profile-guided branch order)"
    ls -la results/orisha-*-a.out
}

case "${1:-all}" in
    validate) check_meta_profiles; run_validate ;;
    build)    check_meta_profiles; run_builds ;;
    smoke)    run_smoke ;;
    pgo)      run_pgo_showcase ;;
    all)
        check_meta_profiles
        run_validate || true
        run_builds
        run_pgo_showcase
        run_smoke
        step "done — board evidence still requires gcannon on Linux (DISCIPLINE.md)"
        ;;
    *)
        echo "usage: $0 [all|validate|build|smoke|pgo]" >&2
        exit 1
        ;;
esac
