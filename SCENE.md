# SCENE.md — orisha

*Read-many, write-rarely. Two clocks: this scene is slow and sticky; the
existing scene (the live repo, `orisha-toolchain`) is fast and live. Scouts
get the ideal user, never this file. The scene condenses from the membrane —
`concepts/` is its source.*

## North star

A web framework where application code is pure Koru and the speed lives in
the compiled stack — the router transform, the pumps, the stdlib. Honest
enough to sit on a public board, fast enough to matter there.

## Ideal user

A Koru programmer writing a real HTTP service. They write `.k` flows and get
a fast server out. The day they have to open a `.kz` file to go fast is a
framework bug, not their job.

## Loose directions

- `httparena/` — the standing instrument: a real benchmark entry, pure Koru
  handlers, validated against the arena's own oracle. It exists to locate
  costs, not to win.
- `challenges/` — standing generators: the cost hunt, the workhorse corpus.
- The pumps (`lib/`): linux/epoll and io_uring — transport is where the
  leader gaps live.

## What it says no to

- Benchmark-shaped stunts. HttpArena is the instrument, not the prize.
- Zig in application code. Primitives live in `.kz` at the framework/stdlib
  floor; logic lives in `.k`.
- A speed claim without a measurement behind it. "Unmeasured" is a legal
  verdict; a guess wearing a number is not.

## Tending log

- 2026-10-14 — planted by arbiters-init. Thin seed condensed from
  `concepts/` (10 frags: measurement honesty, ownership-over-locking,
  serialize-the-invariant, kTLS quiet-point handoff). Condense further as
  the corpus grows.
