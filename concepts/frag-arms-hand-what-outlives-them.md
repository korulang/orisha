# Arms hand what outlives them

**Belief formed (2026-08-23):** an Orisha arm can spawn work that outlives its
own request — a thread holding the connection after the pump has closed the
pump's copy of the descriptor.

**The rule that makes it safe:** ownership, not locking. Duplicate the
descriptor (`dup`) before spawning; hand the thread ONLY the copy and state it
owns outright. The pump closing its descriptor is then irrelevant to the
thread's. Nothing is shared, so nothing can race. Sharing the exchange across
the thread boundary is the forbidden shape — the exchange belongs to the pump
and to the worker executing the arm.

**The bridge:** `orisha/pump:fileno` — one accessor tor beside `raw`. The
contract says what the flow may know; spawning stays raw Zig in the site
program, exactly where `~`-level escape hatches belong.

**Measured:** 60k thread spawn+joins in 1.0s single core; ~100µs added to
request TTFB for dup+spawn+detach; 5.8KB resident per parked stream; zero leak
over 10 minutes / ~24k threads. Contamination harness (B1): 192/192 clean
after per-context allocation, and it catches shared-buffer sabotage as torn
frames — calibrated by sabotage before trusted.

Open: no cancellation (the pump cannot tell a detached thread to stop). The
preferred future shape is a pump `outbound` event so most push loops need no
thread at all. Threads are the general hammer.
