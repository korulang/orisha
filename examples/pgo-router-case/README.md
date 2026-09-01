# Compile-time route reordering — when it pays

Orisha reads `orisha.profile` (nginx combined log) **at compile time** and reorders
`orisha:router` pattern branches so hot paths compare first in the emitted
if-chain. Most web servers do not do this at **binary compile** time.

| Stack | Route order |
|-------|-------------|
| **nginx** | Hand-written `location` blocks — manual PGO at config time |
| **Express / Fastify** | Registration order at process startup |
| **Orisha `orisha:router`** | Source order cold; **`orisha.profile` reorders emitted dispatch** |

Static `orisha:static-router` also reorders embedded bodies (`orderByProfile`).
Twobox measured that surface as **inconclusive** on a fully-resident 23 MB site.
**Dynamic routers** are the favorable case: every request walks the branch chain.

## Constructed case (deliberately favorable)

This directory is a **demo**, not a production harness. It exaggerates what codegen
order vs traffic order looks like:

- **31 routes** — 28 `/admin/*` and `/api/v1/*` decoys declared **alphabetically first**
- **`/baseline11` second-to-last** in source (HttpArena hot path)
- Profile: `httparena/workload.py --profile baseline` → 100k lines, all `GET /baseline11`

Cold first compare: `/admin/alerts`. Warm first compare: `/baseline11`.

## Measured (handler-only microbench, 5M iters, this machine)

```
cold: 38.7 ns/op  (25.81 Mop/s)
warm:  2.6 ns/op  (383.88 Mop/s)
speedup: ~15× (14.5–14.9× on repeated runs; 5M iters)
```

Dispatch only — no socket pump. Real end-to-end gain depends on how much of request
time is routing vs I/O; on HttpArena-shaped skewed traffic with many decoys, the
point is that **the mechanism exists and moves**.

## Run

```bash
cd orisha/examples/pgo-router-case
./bench.sh                  # full cold/warm + results/summary.txt
./bench.sh --show-emission  # print first if-branch only
```

Requires `koruc` on PATH or `KORUC=~/src/koru/zig-out/bin/koruc`.

## Compiler fix (2026-09-01)

Router PGO was silently broken: `loadProfileHits` freed the profile buffer while
hash-map keys still pointed into it. Fixed in `orisha/lib/index.kz` — profile
storage now outlives the sort. Without this fix warm builds did not reorder.

## Honest limits

- Extreme skew + many decoys maximize the gap; uniform traffic or few routes → skip PGO.
- Train and benchmark samples must differ (same distribution, different draw).
- Parameterized routes (`/json/:count`) use prefix scoring — prefer exact paths for demos.

See `httparena/PGO.md` for HttpArena integration.
