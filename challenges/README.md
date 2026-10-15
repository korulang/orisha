# challenges/ — the Orisha challenge catalog

Standing generators, replayed from zero — never a backlog. Each brief seals a
commission once; every replay grounds itself against the catalog's prior
output and must bring something *not already there*. The catalog is the
long-running artifact; a single replay is one slice through it.

Doctrine: `../.claude/ARBITER_DRIVEN_DEVELOPMENT.md` + the `arbiters-challenge`
skill.

## The budget law — binding on every brief in this catalog

**Local-only.** Contestants run in worktrees on this machine. Measurement is
the Docker-VM A/B harness (`HttpArena/frameworks/orisha/build.sh` with
`ORISHA_SRC`/`PUMP`, `wrk`/`gcannon`, `validate.sh` as oracle) plus the
committed board numbers (`site/data/results/*.json`) as reference. No
droplets, no cloud runners. This box produces *deltas*; the board JSONs are
the only absolute numbers.

## Sealed briefs

| # | brief | organ | yields |
|---|-------|-------|--------|
| 001 | [the cost hunt](001_the_cost_hunt.md) | performance | one closed cost — measured, fixed in the stack, cataloged |
| 002 | [the workhorse corpus](002_the_workhorse_corpus.md) | capability | one runnable pure-Koru example, or one pinned framework gap |

## Named candidates — earn their number by recurrence

- **the hostile wire** — robustness organ. A corpus of adversarial request
  shapes (fragmentation, malformed heads, chunked abuse, TLS oddities) as
  runnable repro tests. The validator's 1047-offset suite is the seed shape.
  Seal it when the corpus shows it's wanted.
- **the transport bakeoff** — parked. Pump hardening is convergent work the
  cost hunt already covers; it earns a brief when it recurs.

## How a replay runs

Pick a brief → spawn contestants sealed against it (blind to each other —
variance is the metric) → each self-grounds against this catalog → build,
self-check against the done-gates → judge on the walk → survivors append to
the catalog. Losers evaporate with their worktrees.
