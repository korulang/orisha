---
name: orisha-toolchain
description: Orientation map for the orisha repo — build/test/bench commands, where things live, source of truth, and what bites. Read first on any task here.
---

# orisha-toolchain — the existing scene, read live

Map, not manual. Point at the tools; don't copy their docs.

## What this is

Orisha — Koru's web framework. Compile-time router transform, two pumps
(linux/epoll and io_uring), TLS via `koru-libs/openssl`, the HttpArena
benchmark entry.

## Layout

- `lib/index.k` / `lib/index.kz` — the framework: `orisha:serve`, request
  accessors (`query-param`, `header`, `form`, `body`, `query`), Response
  record + lifecycle (`body_allocated` is freed via `koru_allocator()` —
  allocator pairing is load-bearing).
- `lib/httparena.k` — the HttpArena entry's handlers, **pure Koru**. There
  is no `lib/httparena.kz` and there must never be again: application logic
  in `.k`, primitives in `.kz`.
- `httparena/` — the entry program (`main.k`), harness (`build.sh`,
  `bench.sh`, `compare.sh`, `suite.sh`), `DISCIPLINE.md`, `PGO.md`,
  `refs/dotnet` (ASP.NET reference for same-box A/B).
- `examples/`, `tests/`, `benchmarks/` — corpus, tests, perf workbenches.
- `concepts/` — the membrane corpus (beliefs, lineage via git trailers).
- `challenges/` — standing challenge briefs + the closed-cost catalog.

## Commands

- Compile the entry: `cd httparena && koruc main.k --release=fast` → `a.out`.
  Pump selection: `--build=io-uring` (ring) vs default (linux/epoll).
- HttpArena image from local trees:
  `ORISHA_SRC=… PUMP=io-uring …/HttpArena/frameworks/orisha/build.sh`
  (stages `koru`, `koru-libs/openssl`, `orisha` working trees; image names
  `httparena-orisha` / `httparena-orisha-uring`).
- Validator: `HttpArena/scripts/validate.sh orisha` — the correctness
  oracle. 37/37 is the green bar.
- Local A/B bench: `wrk` via `docker run --rm --network host wrk:local`.
- Board numbers: committed upstream at `HttpArena/site/data/results/*.json`
  (raw gcannon logs under `site/static/logs/`). Mac numbers are deltas —
  the committed JSONs are the only absolute baseline.

## Source of truth

Language semantics: `koru/tests/regression/` (the suite wins over prose).
Entry correctness: the HttpArena validator. This repo's `CLAUDE.md` +
`AGENTS.md` are the canonical standard — read them first.

## Things that bite

- **Stale `a.out` on :8080.** A leftover binary masks the fresh build —
  "green" smokes can be served by the old program. Kill the port, or
  verify the process, before believing any smoke test. (Burned 2026-10.)
- **Obligations are compile-checked.** `String` values carry
  `<view!>`/`<instance!>` debts; every branch must discharge them
  (`free`/`release`/`detach`). The compiler will name the leak — listen.
- **Bare args are name-puns, not positional.** `f(x)` requires the param be
  named `x`; use `f(n: i)` otherwise. Same inside record literals.
- **Board builds clone `main`.** Nothing local counts until it ships —
  `build.sh` exists precisely so validation can run against working trees.
- **Never `zig build` koru or edit `koru_std/` while a regression suite is
  live** — check `pgrep -fl "run_regression|zig build"` first.

## Prose

`prose search "<query>"` for cross-session memory; `prose status` for
recent decisions.
