# Profile-guided optimization (PGO) in Orisha

Orisha has **compile-time PGO** — not LLVM `-fprofile-instr-generate`, but the same idea at the layer Koru controls: **`orisha.profile` in the cwd at compile time**.

## What the compiler does with it

| Surface | Effect |
|---------|--------|
| **`orisha:static-router`** | Reorders embedded response bodies in the binary (hot pages adjacent) |
| **`orisha:router`** | Reorders the generated if-chain — hot patterns compared first |
| **`orisha/httparena:dispatch`** | **No automatic reorder yet** — hand-written Zig if-chain |

Static layout PGO is measured in `benchmarks/twobox/profile-experiment.sh`. Router branch PGO is demonstrated in `examples/pgo-router-case/` — constructed
31-route table, `/baseline11` declared last, baseline profile at compile time.
Measured there (handler-only, this machine): **~15×** cold vs warm dispatch ns/op.
See that README for emission diffs and honest limits.

Until `httparena/main.k` uses `orisha:router`, the HttpArena entry does not get
branch PGO (`./suite.sh pgo` reports identical binaries today).

## HttpArena workflow

Each board profile has a matching traffic mix in `workload.py`:

```bash
cd orisha/httparena

# Generate a profile for the baseline gcannon mix
./workload.py --profile baseline --train profiles/generated/baseline.profile

# Warm compile (copies profile to orisha.profile, then builds)
./build.sh warm baseline

# Full board-shaped mix
./build.sh warm board-mix
```

List mixes: `./workload.py --list`

## Train vs benchmark (no cheating)

Same rule as twobox:

- **`orisha.profile`** = training sample (compiler only)
- **gcannon / board run** = independent traffic (possibly different query params, always validate.sh correctness)

`workload.py` draws a fresh random sample per invocation. Do not compile against the exact request sequence you then benchmark.

## Showcasing PGO on the board

HttpArena has **standard** and **tuned** type rules. A tuned entry is allowed to use framework performance flags — compile-time PGO qualifies.

Planned upstream shape (HttpArena repo, not yet landed):

1. `frameworks/orisha` — standard, cold build
2. `frameworks/orisha-pgo` — Dockerfile copies `profiles/board-mix.profile` → `orisha.profile` before `koruc`

Until `orisha:router` owns HttpArena routes, the showcase is:

1. **Router-based apps** — branch order wins (demonstrate with a router test entry or migrated handler)
2. **Static** — korulang-site / twobox experiment (layout)
3. **Evidence row** — cold vs warm binary diff + gcannon delta on Linux, recorded in `results/`

## Migrating HttpArena handler to router (enables full PGO)

Today `main.k` uses `orisha/httparena:dispatch(req)` for typed access to `Request`/`Response`.

To get profile-guided **branch** order on baseline/json/pipeline:

```
~orisha:handler = orisha:router(req)
| [GET /pipeline] !> ...
| [GET /baseline11] !> orisha/httparena:baseline(req)
| [POST /baseline11] !> orisha/httparena:baseline(req)
| [GET /json/:count] p !> orisha/httparena:json(req, count: p.count)
| [*] !> ...
```

Split `httparena.kz` into `baseline`, `json`, `pipeline` tors — then `./build.sh warm json-comp` reorders branches for json-heavy traffic.

## References

- `lib/index.kz` — `loadProfileHits`, `orderByProfile`, router transform sort
- `benchmarks/twobox/workload.py` — Zipf site workload + held-out wrk script
- `benchmarks/twobox/profile-experiment.sh` — cold vs warm methodology
- `httparena/DISCIPLINE.md` — what counts as evidence
