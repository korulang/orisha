# The threadlocal audit is a sweep, not a spot fix

**Belief:** when the pump went multi-threaded, the one shared thing in the
request path — the response header buffer — was made `threadlocal`, so the
request path was safe.

**Correction (2026-10-05):** one buffer was fixed; the *class* was never
swept. Two more shared request-path arenas survived the audit: `raw_arena`
in pump.kz (the `x.raw` owned copy — one worker's `reset()`+`dupe` overwrites
the slice another worker's router is mid-parse on) and `request_arena` in
index.kz (the 64KB `Request.allocator`, reset per exchange). Measured on
once-campfire-koru: `GET /up` at 16 connections returned ~0.10% non-2xx —
mangled paths hitting 404, stale paths hitting authed routes at 302 — while
a single connection ran 494k requests with zero errors.

**The discipline:** when the concurrency model changes, the audit unit is
"every `var` reachable from the request path," not "the buffer that broke
last time." A spot fix leaves the mechanism armed — and the failure reads
as flaky routing, not as a memory bug, which is why it hid until a real app
hammered it.

**Honest residue:** `conn_states` also claimed lock-free safety on a premise
("no index is ever touched twice") that was false at the accept boundary —
same audit failure, different surface. Comments asserting safety invariants
are claims; check them against the threads that actually run.
