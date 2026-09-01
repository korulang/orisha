# HttpArena discipline

Orisha treats **HttpArena** as a first-class product surface — not a demo, not a sidecar benchmark, not something we narrate before we measure.

We are **not shipping** performance claims until we have **substantial evidence** on the board's own terms. Local `wrk` on a laptop is development feedback only. It does not count.

## What counts as evidence

Evidence is recorded, reproducible, and uses the **same load generators, hardware class, and validation** as the public board.

| Tier | Harness | Use |
|------|---------|-----|
| **Ground truth** | `./scripts/validate.sh orisha` (HttpArena repo) + board gcannon/zrk profiles on Linux | Ship/no-ship, public claims, regression gates |
| **Pre-board** | gcannon mirroring `profiles.sh` on Linux (`--release=fast`, `--build=io-uring` or `--build=linux`) | Optimization decisions before a full board run |
| **Smoke** | `./bench.sh`, `./compare.sh`, Mac `wrk` | Fast iteration only — **never** cited as competitive proof |

A result file without **git rev, host, profile, connections, generator, and validate status** is incomplete and must not drive decisions.

## Scored profiles (our contract)

From `HttpArena/frameworks/orisha/meta.json` — these define whether we are winning:

| Profile | Metric |
|---------|--------|
| baseline | RPS @4096 (gcannon, mixed GET/POST) |
| limited-conn | RPS @4096 (10 req/conn) |
| json-comp | RPS @4096 + 16384 (gzip rotation) |
| json-tls | RPS @4096 (TLS + JSON) |
| latency-1m | CPU µs/req @ pinned 1M req/s |
| latency-10k | CPU µs/req @ pinned 10K req/s |

`pipelined` is reference-only (not composite-scored for frameworks) but still exercised — pump batching must not regress.

**Target:** near-leader normalized score on **each** scored profile, with a deliberate margin over named anchors (genhttp-ioxide class) — not “we beat Actix on wrk once.”

## Engineering rules

1. **validate.sh green first.** Correctness is the floor; RPS without validation is worthless.
2. **Fix the framework, not the story.** Regressions in `lib/pump.kz`, `lib/index.kz` (`answer`), TLS, and alloc paths are Orisha defects — never HttpArena-only workarounds that hide them.
3. **Board build shape:** `koruc main.k --release=fast --build=io-uring` (fallback `--build=linux`). Debug Mac kqueue is not the score path.
4. **No false anchors.** Compare against board entries and our own pinned CSVs (`benchmarks/results/`), not arbitrary Go stdlib servers or mismatched wrk settings.
5. **Pre-render / fast-path pattern** (proven on `/pipeline`: ~+25%) applies systematically — pre-rendered HTTP where validate allows, threadlocal integer bodies, skip header work when headers are absent, no TLS tax on cleartext profiles.
6. **No marketing commits.** README, blog, Discord: silence until tier-1 evidence exists for the claim being made.

## Accommodating suite (local checklist)

`./suite.sh` runs the full local contract:

| Step | Command | Purpose |
|------|---------|---------|
| Profile coverage | `suite.sh` (meta check) | All seven `meta.json` tests have routes |
| Correctness | `suite.sh validate` | `./scripts/validate.sh orisha` |
| Builds | `suite.sh build` | cold + warm PGO matrix via `./build.sh` |
| PGO showcase | `suite.sh pgo` | cold vs warm binary diff |
| Smoke | `suite.sh smoke` | `bench.sh` — not evidence |

Supporting scripts: `workload.py` (profile mixes), `build.sh` (cold/warm), `bench.sh`, `compare.sh`.

## Profile coverage matrix

Every subscribed test must be **correct** (validate) and **fast** (gcannon on Linux) before we claim it.

| Profile | Endpoint(s) | Generator | Build notes |
|---------|-------------|-----------|-------------|
| baseline | `/baseline11` GET+POST CL+chunked | gcannon @4096 | warm: `./build.sh warm baseline` |
| limited-conn | same | gcannon `-r 10` | same handler as baseline |
| pipelined | `/pipeline` | gcannon `-p 16` | pre-render response; pump batching |
| json-comp | `/json/{25,40,50}?m=` gzip | gcannon @4096/16384 | warm: `./build.sh warm json-comp` |
| json-tls | `/json/…` on `:8081` TLS | wrk+lua / gcannon | Docker sed adds TLS |
| latency-1m | `GET /baseline11?a=1&b=2` | zrk @1M req/s | idle CPU — no busy-wait |
| latency-10k | same | zrk @10K req/s | standing cost profile |

Reference-only (still implement): `pipelined` on the board is not composite-scored for frameworks but proves pump pipelining.

## PGO (compile-time, showcase)

Orisha reads **`orisha.profile`** at compile time (nginx combined log format).

- **Static router:** hot response bodies laid out adjacently in the binary (`orderByProfile`)
- **Dynamic router:** hot pattern branches first in the if-chain (`loadProfileHits` in router transform)
- **HttpArena dispatch proc:** manual branch order today — migrate to `orisha:router` for full PGO (see [`PGO.md`](PGO.md))

Workflow:

```bash
./workload.py --profile board-mix --train profiles/generated/board-mix.profile
./build.sh warm board-mix    # PUMP=io-uring for board-shaped builds
```

Board **tuned** entry (future upstream): Dockerfile copies a pinned profile before `koruc` — standard vs `orisha-pgo` league per HttpArena type rules.

PGO evidence requires **held-out gcannon** (train profile ≠ benchmark sequence), same discipline as `benchmarks/twobox/profile-experiment.sh`.

## Where code lives

```
orisha/lib/pump.kz          ← accept loop, pipelining, io_uring/epoll/kqueue, TLS
orisha/lib/index.kz         ← answer(), header formatting, router transforms
orisha/lib/httparena.*      ← HttpArena oracle routes (not public API)
orisha/httparena/           ← board entry (main.k, harness scripts, results/)
HttpArena/frameworks/orisha ← Dockerfile, meta.json (upstream board)
```

Framework wins lift **every** consumer. Route wins lift **profiles**. Both are in scope; neither replaces validate + gcannon.

## Results hygiene

- `./bench.sh` / `./compare.sh` → `httparena/results/` (local smoke; gitignored)
- Board runs → commit CSV or log snapshot with rev + machine + `./scripts/validate.sh` exit code
- Never overwrite a baseline snapshot without noting what changed in the framework

## Current status

**Gate 0 — correctness (local Docker): green** — 2026-09-01, `orisha@60a09c3`, `koru@41a417a7`.

```bash
cd orisha/httparena && ./validate-local.sh --skip-build
# or: VALIDATE_SKIP_BUILD=1 ./scripts/validate.sh orisha  (HttpArena repo, bash 5 + GNU grep)
```

| Check | Result |
|-------|--------|
| `validate.sh orisha` | **37 passed, 0 failed**, exit 0 |
| baseline + anti-cheat + 4 named TCP splits | pass |
| exhaustive frag (9 shapes, 1047 offsets) | **9/9 pass** |
| pipelined, json, json-comp | pass |
| json-tls (TLS 1.3, mounted cert, JSON over `:8081`) | pass |
| latency-1m / latency-10k / limited-conn | covered via baseline handler checks (no separate validate block) |

Log: `orisha/httparena/results/validate-local-latest.txt`. Fix: `pump.kz` honors `Connection: close` and shuts down the socket after reply so `validate-frag.py` sees TCP EOF.

**Still unmeasured for external claims:** gcannon/zrk RPS and latency on board Linux (`--build=io-uring`). Mac Docker validate ≠ board score path. Treat all Mac `wrk` numbers as smoke only.
