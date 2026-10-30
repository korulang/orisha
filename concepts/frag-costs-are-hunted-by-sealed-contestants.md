---
type: belief
id: frag-costs-are-hunted-by-sealed-contestants
provenance: the 001_the_cost_hunt replay, 2026-10-15 — four sealed
  contestants, four organs, three stack-level wins and one clean
  rejection; evolved 2026-10-28 when a commissioned cax41 race
  contradicted two clauses at once — the Docker-VM oracle had been
  suppressing orisha's number, and a workload-specialized drive
  variant beat both drive|io-uring (+7.8%) and ioxide (+10.9%)
ts: 2026-10-28
---

# Costs are hunted by sealed contestants, and the arena is the instrument

Orisha works under Arbiter-Driven Development: performance work happens
through sealed challenges replayed by contestants in worktrees, judged on
the walk, and recorded in `challenges/catalog/` — closed, named-open, or
rejected-with-evidence, all three first-class outcomes.

**The ruling:** HttpArena is the instrument that locates cost, never a
prize to be won. A fix belongs in the stack — pump, serializer,
compiler, stdlib — never in the handler, and never handler-shaped.
A workload-specialized `~proc` variant is a stack fix with a selector:
`drive|race` (h1-only, no TLS/h2c/ws/parks) is what the arena entry
selects while `drive|io-uring` stays the general default — the same
shape ioxide chose when it shipped a hand-written reactor instead of a
framework. Application logic stays in Koru; a bespoke Zig handler was
the scored entry's original sin and it is gone.

**The budget is law, and the law was wrong once:** the Docker-VM race
is the cheap oracle, but its cgroup/memcg stack is a measurement
artifact — it charged orisha ~10% CPU on socket memory that bare metal
does not. A commissioned arm64 metal box (Lars-approved, destroyed
after the run) inverted the local deficit into a real lead. So: the VM
for iteration, metal for verdicts — when the residual sits inside the
VM's noise floor, the honest instrument is a droplet, not another VM
race. Variance is the metric — a contestant that re-claims a closed
cost has failed the grounding, not found a bug.

**Open questions:** whether the epoll pump earns continued investment
now that it shares the ring pump's shape; whether `002_the_workhorse_corpus`
produces a third organ (the hostile-wire corpus is named, unsealed);
whether catalog growth stays a Gardener act or becomes part of each
contestant's done-gate.
