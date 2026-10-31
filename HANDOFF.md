# Handoff — Orisha HTTP/3 throughput gap

## What this is

Orisha is a web server written in Koru (compiles to Zig). It runs an
io_uring worker pump (`lib/pump.kz`, `~proc drive|io-uring`). We wrote a
native QUIC v1 + HTTP/3 stack inside that pump (`lib/pump.quic.kz`, ~2900
lines): OpenSSL 3.5 QUIC TLS callbacks for the handshake, then our own
HKDF/AES-128-GCM packet protection, header protection, coalesced
Initial/Handshake/1-RTT processing, streams, flow control, ACK/loss
recovery, PTO, DPLPMTUD, QPACK (static table only), and h3
request/response mapping onto the existing HTTP handler path.

Status: **functionally complete, validator 80/0 on the arena's own
correctness suite.** The remaining problem is throughput, not correctness.

## The actual problem

On the same box, same client (`h2load-h3`, nghttp2/ngtcp2 over quictls),
same shape, alternating containers:

| shape | orisha | agensio (leader) |
|---|---|---|
| `-c1 -m64` /baseline2 (h3) | ~139k req/s | ~176–221k req/s |
| `-c1 -m64` /static/reset.css (h3, ~2.4KB br body) | ~30k req/s | ~80k req/s |

We are ~1.4x behind on baseline-h3 and ~2.6x behind on static-h3 at the
single-connection shape. The residual gap is per-request latency on a
single connection (~7us/req budget vs ours ~7.2us baseline2 / ~33us
static). It is NOT a protocol bug — the last real bug is fixed (below).
It is ordinary per-request/per-packet cost that is still higher than
agensio's (C++/asio/OpenSSL stack).

For reference: orisha's h1 arms on the same box run baseline 1.15M,
pipelined 11.67M, echo-ws 1.24M req/s — the TCP stack is fine. The gap
is specific to the QUIC/H3 data path.

## What was already done (all merged on branch `h3/quic`, HEAD includes)

Worktree: `/tmp/h3ctx/orisha` (branch `h3/quic`). Auxiliary worktrees
`/tmp/h3ctx/p1..p5`, `/tmp/h3ctx/m1` hold the contestant branches.

- `5728e69` runtime-static file cache keyed on (mtime,size): serve-file
  was doing access+access+open+read+close+allocs per request (~15x win
  locally). lib/index.kz.
- `aba30d1` (C1): cached AES key schedules on QKeys; removed per-packet
  ArrayList allocs in quicBuildPacket; frame_pool recycling.
- `1de655a` (C2): sendmmsg datagram bursts (32/flush); tx_ready stream
  queue replaces all-streams scan; one-pass ACK-range processing;
  quicDetectLoss compaction.
- `779c196` (C3): hardware AES on arm64 — HwAes128/HwAesGcm mirrors of
  zig std armcrypto, `.arch_extension aes` asm, getauxval(AT_HWCAP)
  dispatch; needed because zig native CPU detection reports aes=false
  in this VM (see TOOLCHAIN ISSUE below).
- `5e61f74` (C5, THE BIG FIX): trailing 1-RTT packet coalesced behind
  the Finished flight was silently dropped; early 1-RTT dgrams arriving
  before app RX keys also dropped. Client declared pn=0 lost, cwnd
  collapsed to ~5KB permanently → bimodal 25-77k req/s. Fixed by
  feeding short-header tails to the app path + bounded early-packet
  buffer (8 dgrams/16KB). → stable ~140k.
- `e11fef3` (C4): hardware GHASH — pmull/pmull2 ladder mirroring zig
  ghash_polyval.zig, same detection gap as AES. Microbench: 5-10x on
  the whole AEAD op; e2e parity on this box (crypto share already
  small).

## Suspects for the remaining ~1.4x/~2.6x gap (uninvestigated)

- Per-request handler latency on h3 vs h2/h1 paths (static ~33us/req
  vs baseline ~7us — the gap is larger on static, so look at the
  H3/QPACK encode + DATA frame path + the stat syscall still in
  serve-file).
- Per-packet crypto still costs even with hw AES/GHASH (encrypt 1344B
  ~0.5-1us at these sizes — probably not dominant).
- receive→serve→send latency through the ring (CQE drain, quicServe,
  h3Reply scheduling vs agensio's single-loop).
- ACK/response batching policy vs ngtcp2's (cloned at /tmp/h3ctx/ngtcp2
  and /tmp/h3ctx/quiche for reference — read them, don't guess).
- SO_REUSEPORT pins each QUIC conn to ONE worker; -c64 spreads across
  workers, -c1 never does. Multi-conn numbers benefit from worker
  parallelism; single-conn numbers are single-core.
- Whether agensio uses GSO/larger datagrams earlier, or posts sends
  differently (recvmsg+sendmsg vs our poll_add+sendto/sendmmsg).

## Environment quirks that WILL waste your time if you don't know them

- **Docker Desktop on macOS**: the VM's UDP/loopback timing is noisy;
  ±50% run-to-run variance is normal. Judge deltas only on interleaved
  alternating runs on a quiet box (check `docker ps` — ANY stray orisha
  container on :8443 splits traffic via SO_REUSEPORT and poisons the
  measurement).
- **`taskset` is missing in the harness's h2load docker images** —
  benchmark-lite's h2/h3 arms all record 0 req/s on macOS for every
  entry. h1 (gcannon) works. Measure h3 directly with h2load-h3.
- **`zig build` native in this VM detects `cpu=generic aes=false`** —
  zig's mrs ID-register probe fails while HWCAP_AES is set. This is a
  real Zig toolchain gap (worth an upstream issue): std armcrypto AES
  and clmul GHASH are silently skipped unless you do what we did —
  runtime getauxval dispatch + `.arch_extension aes` asm blocks.
- Port forward (`-p 8443:8443/udp`) through Docker Desktop's bridge can
  wedge/degrade — use `--network host` for measurement.
- koruc lives at `~/src/koru/zig-out/bin/koruc`; the httparena build
  dir needs `koru` and `koru-libs` checked out at `../../` relative to
  orisha (or symlinked); image build is
  `docker build -f /tmp/h3ctx/Dockerfile -t <tag> <ctx>` where ctx has
  `orisha/` (export via `git archive HEAD | tar -x -C ctx/orisha`).
- The arena validator: `VALIDATE_SKIP_BUILD=1
  scripts/validate.sh orisha-uring` in ~/src/HttpArena with
  `/tmp/h3ctx/gnubin` on PATH (BSD grep lacks -P); needs your image
  tagged `httparena-orisha-uring`. Real score line: 80/0 or 78/0/1
  (1 skip = h3 needs `h2load-h3` image named exactly).
- Commit hooks in this repo require `## World Model` + `## Membrane`
  sections in every commit message; use `Signals: acknowledged-none` /
  `Evolution: acknowledged-none` for pure-mechanism commits, or stage a
  `concepts/frag-<id>.md` with OKF frontmatter when a belief changed.

## How to measure (exact commands used for every number above)

Server:
    docker rm -f js; docker run -d --name js --network host \
      --security-opt seccomp=unconfined \
      -v ~/src/HttpArena/certs:/certs:ro \
      -v ~/src/HttpArena/data/dataset.json:/data/dataset.json:ro \
      -v ~/src/HttpArena/data/static:/data/static:ro <image>

Baseline-h3 single-conn:
    docker run --rm --network host h2load-h3:local --alpn-list=h3 \
      "https://localhost:8443/baseline2?a=1&b=1" -c 1 -m 64 -t 1 -D 8

Static-h3:
    same, but "https://localhost:8443/static/reset.css" -H "Accept-Encoding: br;q=1"

Images present locally: orisha-m2 (merged HEAD), race-agensio,
race-fib, race-fib-tuned, httparena-orisha-uring (pre-merge base).

## Rules the previous agent got punished for breaking

- Report only numbers you ran yourself. A claim from a report/script is
  a claim until re-run.
- No commissioned hardware while behind locally (Hetzner exists;
  `~/.config/hcloud/token`, ssh key `~/.ssh/koru_bench`; delete the box
  after).
- Don't attribute constraints to the user you can't point to verbatim.
- The user wants the project to WIN the board, not be validator-green.
  "Behind" gets reported as "behind" immediately.
