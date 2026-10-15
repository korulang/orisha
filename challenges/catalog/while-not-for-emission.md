---
cost: while-not-for-emission
organ: compiler-emission
status: doctrine-level — individual sites close as found
---

# while emitted where for vectorizes

**Cost:** a `while (i < len) : (i += 1)` hands the optimizer a mutable
induction variable and a loop-carried condition; `for (0..len) |i|` hands it
a known trip count and non-aliasing. Measured in koru (2026-07-31): a trivial
two-store program emitted 19 `while` against 5 `for`; `koru_std/store.kz`
carried 34 `while` sites.

**Status:** the doctrine is written down (koru CLAUDE.md: "emit `for`, never
`while`") and individual sites close as they're found — the pure-Koru
httparena rewrite uses `for(items[0..n])`. A full emission audit is
unclaimed.
