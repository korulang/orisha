---
cost: uring-coalesce-wait-park
organ: transport (io_uring pump, completion path)
status: rejected (cost didn't reproduce)
---

# the bounded completion-coalesce wait

**Suspected cost:** `run()`'s adaptive `wait_nr` rides `got/2` up to
`WAIT_COALESCE_MAX=32`; `ringWaitTimeout` then parks the worker in
`io_uring_enter(GETEVENTS|EXT_ARG)` for up to `WAIT_COALESCE_NS=20_000`ns
waiting for completions that may not exist. Under lockstep pipelined load a
parked wait is dead latency sitting on top of responses already ready —
candidate for the board's pipelined gap (40.5M vs ioxide 53.4M, −24%).

**Prior suspicion ruled out first — per-response send overhead.** Counter
instrumentation (`PUMP_STATS`, since removed) under `gcannon -c512 -p16`
showed ~15–16 responses per send SQE and ~1.65KB per send — the send plan
already coalesces a full pipeline burst into one writev. The pending leg
never fired (`pend=0`). Per-response sends are not the cost.

**What was actually measured** (local Docker VM, `/pipeline`,
`gcannon -t8 -c512 -p16 -d8s`, `--security-opt seccomp=unconfined`):

- Multi-worker runs: drains averaged ~1.6 CQEs — arrival-limited, so
  `wait_nr` stayed 1 and the timed wait never ran. The mechanism is dead
  code under that shape.
- Single-worker (`--cpuset-cpus=0`) aggregates 512 conns on one ring:
  drains ~197 CQEs, coalesced waits engaged, and the timeout counter fired —
  `touts=23` in 8s (~4% of coalesced waits). The park exists but is bounded:
  every wait parks ≤20µs, so total parked time is bounded at
  waits × 20µs ≈ 19ms per 8s run — **≤0.2% of runtime**. It cannot explain
  a 24% gap.

**A/B, same shape, interleaved, one listener at a time on :9101** —
base `orisha@9530fed` vs timeout-decay fix (drop `wait_nr` to 1 after a
timed-out wait, re-coalesce only after `got>=64`):

- Instrumented fix, 10 rounds: fix won 6/10, mean +0.7%; best-per-arm
  **base 350.59K > fix 337.59K**.
- Clean fix (counters dead-stripped), 6 rounds: fix won 2/6,
  means base 329.85K vs fix 322.59K (−2.2%); bests 336.73K vs 338.59K.
- Third arm (`WAIT_COALESCE_MAX=1`, coalescing disabled entirely): ≈ base —
  the whole bounded-wait machinery is within noise, both directions.

**Verdict: rejected.** The park is real but arithmetically bounded at ~0.2%
of runtime and no interleaved pair showed a reliable delta. The fix was
validated correct (validate.sh 37/37) and then reverted — nothing landed.
Experiment diff preserved at `challenges/catalog/uring-coalesce-wait-park.diff`.

**Caveats for the next contestant:** all numbers are this Mac Docker VM
(load avg 6–30 from sibling hunts during measurement); the board's
`-c4096` flood may time out far more often than 4%, so the mechanism is
not disproven on the board — only disproven *here* as a ≥1%-scale cost.
Perf showed userspace flat (dispatchHttpSlice 8%, everything else <2%);
the remaining pipelined gap is in the kernel path — syscall count per
burst, iovec processing, or recv sizing, not response batching.
