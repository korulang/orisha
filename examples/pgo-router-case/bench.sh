#!/usr/bin/env bash
# Cold vs warm compile — dispatch microbench for profile-guided route reordering.
set -euo pipefail
export PATH="/usr/bin:/bin:/opt/homebrew/bin:${HOME}/.local/bin:${PATH:-}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ORISHA_ROOT="$(cd "$HERE/../.." && pwd)"
cd "$HERE"

KORUC="${KORUC:-/Users/larsde/src/koru/zig-out/bin/koruc}"
ZIG="${ZIG:-zig}"
ITERS="${ITERS:-5000000}"
SHOW="${1:-}"

first_branch() {
  rg -n 'if \(std\.mem\.eql\(u8, \(req\)\.method' output_emitted.zig | head -3
}

# koruc reads orisha.profile from compile cwd; emit lands beside the .k source.
compile() {
  rm -f "$ORISHA_ROOT/orisha.profile" "$HERE/output_emitted.zig"
  if [[ -f "$HERE/orisha.profile" ]]; then
    cp "$HERE/orisha.profile" "$ORISHA_ROOT/orisha.profile"
  fi
  (cd "$ORISHA_ROOT" && "$KORUC" "examples/pgo-router-case/main.k" --release=fast)
}

build_cold() {
  rm -f orisha.profile output_emitted.zig
  compile >/dev/null 2>&1
  echo "==> cold emission (first branch):"
  first_branch
  cp output_emitted.zig results/output_emitted.cold.zig
}

build_warm() {
  rm -f orisha.profile output_emitted.zig
  python3 "$ORISHA_ROOT/httparena/workload.py" --profile baseline --train "$HERE/orisha.profile"
  compile 2>&1 | rg "ROUTER TRANSFORM.*profile|hottest" || true
  echo "==> warm emission (first branch):"
  first_branch
  cp output_emitted.zig results/output_emitted.warm.zig
  rm -f orisha.profile "$ORISHA_ROOT/orisha.profile"
}

bench_one() {
  local tag="$1"
  "$ZIG" build --build-file build_bench.zig run -- "$ITERS" 2>&1 | tee "results/${tag}-dispatch.txt"
}

mkdir -p results
build_cold
if [[ "$SHOW" == "--show-emission" ]]; then exit 0; fi
bench_one cold

build_warm
bench_one warm

{
  echo ""
  echo "==> summary (GET /baseline11, ${ITERS} iters, handler only)"
  echo -n "cold: "; cat results/cold-dispatch.txt
  echo -n "warm: "; cat results/warm-dispatch.txt
  python3 - "$ITERS" <<'PY2'
import re, pathlib, sys
iters = sys.argv[1]
cold = pathlib.Path("results/cold-dispatch.txt").read_text()
warm = pathlib.Path("results/warm-dispatch.txt").read_text()
def nsop(s):
    m=re.search(r"([0-9.]+) ns/op", s)
    return float(m.group(1)) if m else None
cn, wn = nsop(cold), nsop(warm)
summary = pathlib.Path("results/summary.txt")
lines = [
    f"GET /baseline11 dispatch microbench ({iters} iters)",
    f"cold: {cold.strip()}",
    f"warm: {warm.strip()}",
]
if cn and wn:
    lines.append(f"speedup: {cn/wn:.2f}x (cold ns/op / warm ns/op)")
summary.write_text("\n".join(lines) + "\n")
print("\n".join(lines[-1:] if cn and wn else []))
PY2
}
