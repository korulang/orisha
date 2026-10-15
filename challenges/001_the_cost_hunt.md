---
challenge: cost-hunt
kind: frame
status: standing
yields: one closed cost — measured, fixed in the stack, cataloged
family: performance
---

# Challenge 001 — the cost hunt

*Walker context — the recurrence that earned this frame. One session, five
real costs found and closed the same way: dead dispatch branches, a
per-request dataset read+parse, a `std/compress:gzip` allocator mismatch
(page-allocated buffer freed through `koru_allocator()` — glibc aborts),
`while` loops emitted where `for` vectorizes, and the entire epoll-vs-io_uring
pump gap (501k vs 4.1M req/s on the board). The loop kept happening bespoke;
it is a generator now.*

*Board position (committed `site/data/results/`, gcannon @4096, Threadripper
3995WX): `orisha-uring` ties the leaders on baseline (4,114,610 vs edixoi's
4,140,626) and beats ioxide on json-comp by 1.8×. Where we actually trail:
pipelined 40.5M vs 53.4M (−24%) and json-tls 1.48M vs 1.80M (−18%). The plain
`orisha` entry (epoll pump) sits at 501k — an 8× pump gap, not a handler gap.*

---

## The brief (sealed — you are the contestant)

Find ONE real cost the stack pays and close it. You choose where to look —
that choice is the variance this challenge runs on, so read the catalog first
and do not re-claim a cost that is already shut.

Candidate organs, deliberately unordered: the io_uring pump (pipelined write
batching, the kTLS TX path — the two known board gaps), the linux/epoll pump,
compiler emission (what `output_emitted.zig` actually generates for the hot
path), stdlib data structures (String churn, allocator pairing), the response
head render, the JSON parse/emit pipeline.

The rules that make an artifact count:

- **Measure first, fix second.** Name the cost with a measurement — a number
  from the instrument, not a hunch. A cost you cannot demonstrate does not
  exist.
- **The fix lands in the stack.** Compiler, stdlib, framework, pump —
  general and honest. Never in the HttpArena handler, never shaped to the
  benchmark. `lib/httparena.k` stays pure Koru; if your fix needs the
  handler to change to benefit, it isn't a stack fix.
- **The validator is the oracle.** `validate.sh orisha` must stay 37/37.
  A faster wrong answer is a loss, not a cost hunt.
- **Local-only.** Worktrees on this box, Docker-VM `wrk`/`gcannon` A/B —
  `ORISHA_SRC=<your worktree> PUMP=<pump> HttpArena/frameworks/orisha/build.sh`
  then `docker run --rm --network host wrk:local -t 6 -c 512 -d 12s <url>`.
  Same shape for both arms or the delta means nothing. No droplets.
- **Honest deltas.** Report the A/B at the level it was measured — this box
  produces deltas, and the committed board JSONs are the only absolute
  reference. A number extrapolated to the board is a *projection*; say so.

## Done-gates (self-check before judging)

1. The cost is named with a before-measurement from the instrument.
2. The fix is landed in compiler/stdlib/framework/pump code and survives
   `validate.sh` at 37/37.
3. An after-measurement shows the delta — same box, same load shape,
   both arms — or the entry honestly states the instrument can't see it.
4. The catalog entry exists: `challenges/catalog/<slug>.md` with the cost,
   the measurement pair, the diff pointer, and the organ it touched.

## The catalog

`challenges/catalog/` — one file per closed cost. Seeded from the founding
session: `gzip-allocator-pairing`, `per-request-dataset-reread`,
`dead-dispatch-branches`, `while-not-for-emission`, `epoll-pump-ceiling`.
Each entry is runnable evidence (a measurement + a landed diff), not prose —
a closed cost that can't be re-measured is a lie waiting to mislead the next
replay.
