---
cost: transform-site-dropped-continuation
organ: language
status: named-open
---

# transform sites silently drop unclaimed branch continuations

**Cost:** not a runtime cost — a silent mis-compile. A branch arm written
against a transform invocation that the transform does not claim (e.g.
`| done` on `std/store:query`, which declares only `! query` / `! first` /
`| none`) parses as an ordinary branch continuation, the transform replaces
the invocation node with emitted code (the sweep loop, the sweeprun call),
and the arm evaporates: it is never emitted and nothing diagnoses it.
Measured: a `| done |> print` continuation after a `query` site produced a
green compile and the "after" line never printed — in an app that arm
carried `respond-json`, so the emitted handler reached end-of-body on a
non-void Zig function and failed the build two layers downstream, far from
the real defect.

**Why it bites:** every streaming construct the language teaches —
`read-lines`, `for` — owns a `| done` branch, so writing `| done` after a
`query` sweep is the natural spelling. The site accepts it, then drops it.

**Fix direction:** refuse unclaimed `|` branch arms on transform sites
(arm-name validation against the site's declared arms — the same check
KORU161 already applies to `!` arms), or give `| done` after-loop emission
semantics. Refusal is the smaller surface and preserves today's meaning.

**Working idiom meanwhile:** name the sweep as a tor; the caller's `|>`
chain continues past the call, and the tor's inputs ride the sweep's
capture threading into the body.

**Repro:** koru `tests/regression/600_STDLIB/690_STORE/690_364_query_unclaimed_done_arm_refused`
— pinned as MUST_ERROR; if done-continuation semantics land instead, it
flips to MUST_RUN with the after-line in expected output.
