# Orisha on HttpArena

**Read [`DISCIPLINE.md`](DISCIPLINE.md) first.** HttpArena is a first-class surface in Orisha: no performance claims without board-grade evidence (`validate.sh` + gcannon on Linux). Local `wrk` is smoke only.

**Orisha** is the framework (`import orisha`). **This directory** is the HttpArena entry — the genhttp-kestrel shape: a small `main.k` that wires routes and listens.

```
orisha/lib/httparena.*   ← route implementations (orisha/httparena:dispatch)
orisha/httparena/        ← benchmark entry (this tree)
```

Route code lives in `lib/httparena.k` + `lib/httparena.kz` because Koru only nests `orisha/httparena:*` under the framework module from that companion pair. It is **not** part of the public Orisha API — it exists so the entry can call `orisha/httparena:dispatch(req)` with correct `Request`/`Response` types.

## Run locally

```bash
cd orisha/httparena
DATASET_PATH=./data/dataset.json koruc main.k && ./a.out
```

Smoke:

```bash
curl 'http://localhost:8080/baseline11?a=13&b=42'   # 55
curl 'http://localhost:8080/pipeline'               # ok
curl -k 'https://localhost:8081/baseline11?a=5&b=7' # 12 (enable TLS — see main.k / Dockerfile)
```

## wrk (local load test)

Build ReleaseFast and hammer the three oracle routes:

```bash
cd orisha/httparena
./bench.sh
```

One endpoint, or leave the server up for manual runs:

```bash
./bench.sh pipeline
./bench.sh --serve-only
wrk -t4 -c256 -d10s http://127.0.0.1:8080/pipeline
```

Tune with env vars: `DURATION=30s CONNECTIONS=4096 THREADS=8 ./bench.sh`.

## Honest comparison (`./compare.sh`)

Same Mac, same wrk flags: Orisha vs a tiny Go `net/http` reference on `/pipeline` and `/baseline11`, plus HttpArena board numbers printed **for context only** (different CPU, gcannon not wrk, mixed POST baseline, pipelined `-p 16`, gzip json rotation).

```bash
./compare.sh
# writes results/compare-<timestamp>.txt
```

The official HttpArena board uses **gcannon** for baseline/pipeline/json-comp — `./scripts/validate.sh orisha` from the HttpArena repo. This harness is for quick local iteration.

## HttpArena suite

Board entry: `HttpArena/frameworks/orisha/` — `./scripts/validate.sh orisha`

See **[`DISCIPLINE.md`](DISCIPLINE.md)** for evidence tiers, scored profiles, and ship gates.

## Suite (cover everything)

```bash
./suite.sh          # validate + builds + PGO diff + smoke
./suite.sh validate # needs HttpArena checkout at ../../HttpArena
./build.sh warm board-mix
```

- **[`PGO.md`](PGO.md)** — compile-time `orisha.profile`, workload mixes, board showcase plan
- **`workload.py`** — generate profile logs per HttpArena profile shape
- **`profiles/`** — mix catalog and generated training logs
