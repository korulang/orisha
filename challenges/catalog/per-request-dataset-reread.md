---
cost: per-request-dataset-reread
organ: framework
status: closed
---

# per-request dataset re-read + re-parse

**Cost:** the pure-Koru `/json` handler opened `DATASET_PATH`, streamed the
file into a `{"items":`-wrapped buffer, and schema-parsed the full item list
on *every request*. Now closed at the framework level.

**Fix:** two pieces, both general.

1. `orisha:init` — a new abstract framework tor (`lib/index.k`,
   `[abstract]pub tor init {} | ready | failed string`, default `=> ready`).
   `orisha:serve` invokes it once on the calling thread before
   `orisha/pump:run` stands up the listener or any worker, and `| failed`
   refuses startup. Anything init writes is visible to every worker by
   thread-spawn ordering — custody that is never written again needs no lock.
2. App-side custody in `lib/httparena.k`: `std/store:new(dataset)` holds one
   row per item — the item's rendered wire fragment (an owned
   `*String<instance!>` column) beside its `price*quantity` base — and
   `dsmeta` holds the seeded count. `orisha:init` reads+parses the file once
   and renders each fragment once. Per request, `serve-items` sweeps the
   store: `sweep-custody` visits rows, `emit-custody` appends fragment +
   `total = base*m` + `}` for ordinals under the clamped count, and
   `respond-json` wraps `{"items":[...],"count":N}` with the existing
   gzip/plain negotiation. No filesystem call, no parse, no schema walk in
   the request path (emitted Zig: `read_lines` is reachable only from
   `init_event`; `serve_items_event` is a loop over store columns).

**Compiler/stdlib repairs the fix required** (all general, none
benchmark-shaped — koru worktree):

- `koru_std/store.qcaps.kz` — `lookupReturnIn` now reads
  `ed.return_phantom`, requalifies it `mod:!state` in the declaring module's
  spelling, and propagates it into return-binding captures; bare `*T`
  returns gain the declaring module path. Without this a captured
  `take()`-bound `*String` lost its tracked phantom (KORU030 "no tracked
  phantom state").
- `koru_std/store.new.kz` — the synthesized plural store cell is emitted
  under `home_ns`, not `flow.module`, matching the singleton-store path; a
  store declared in a namespaced module (`orisha.httparena`) previously
  emitted its cell at the file-module name and the sweep dereferenced a
  member that did not exist.

**Measured** (this box, Docker VM, `wrk -t4 -c64 -d10s`,
`/json/50?m=2`, best-of per arm — the box is noisy, worst-case pair still
holds 3.8x):

| arm  | before (req/s) | after (req/s) | speedup |
|------|---------------:|--------------:|--------:|
| plain | 7,949.66      | 40,009.17     | 5.0x    |
| gzip  | 8,422.10      | 34,800.08     | 4.1x    |

(Second baseline plain run printed 5,830 — the delta is wider than the
noise either direction.)

**Correctness:** `/json/{1,7,50,200}?m={2,3}` verified against
`data/dataset.json` — every field byte-faithful, `total = price*quantity*m`,
count clamps to custody size, gzip arm decompresses to the identical body.

**Residual named gap:** `transform-site-dropped-continuation` — a `| done`
arm written on a `std/store:query` site compiles silently and never emits.
The working idiom (used here) is naming the sweep as a tor and continuing
the caller's `|>` chain past the call. Pinned as a refusal in
koru `tests/regression/600_STDLIB/690_STORE/690_364_query_unclaimed_done_arm_refused`.
