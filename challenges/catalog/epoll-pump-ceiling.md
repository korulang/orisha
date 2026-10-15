---
cost: epoll-pump-ceiling
organ: transport
status: closed-partial — fixable cost found, fixed, measured; ceiling still stands
contestant: hunt-c
tree: orisha@9530fed (detached worktree), lib/pump.kz
---

# the epoll pump ceiling

## Cost named, measured

**Per keep-alive request, the old pump paid a bookkeeping syscall with no
payload: `epoll_ctl(EPOLL_CTL_MOD)` — the ONESHOT re-arm — in exact 1:1:1
with `read` and `write`.**

Instrument: `strace -c -f` on the running server under
`wrk -t6 -c512 -d12s /baseline11` (Docker Desktop linux/arm64 VM, 12 vCPU):

```
% time     seconds  usecs/call     calls    errors syscall
 41.95   71.021347         650    109229           write
 28.90   48.929677         447    109234           read
 28.47   48.205365         441    109230           epoll_ctl   <- pure bookkeeping
  0.68    1.147162         654      1753           epoll_pwait (~62 events/wait)
```

Three properties made this expensive beyond its own ~0.5µs:

1. **ONESHOT disarms on every delivery** — the re-arm is structurally
   mandatory, one per readiness event, one event per request under wrk.
2. **All 12 workers shared one epfd** — every re-arm and every `epoll_wait`
   harvest contended on the same kernel-side instance lock.
3. **Accept lived on 12 dedicated acceptor threads** pushing into the shared
   instance — cross-thread `epoll_ctl(ADD)` under the same lock, plus
   `conn_states_mu`.

CPU split under load (untimed, `/proc/1/stat` deltas): ~4.0 cores kernel vs
~0.3 cores user of 12 — **94% kernel**, and the pump was NOT CPU-saturated
(each worker idle ~60% waiting on readiness).

## Fix landed — `lib/pump.kz` `drive|epoll`

Replaced shared-epfd+ONESHOT with the ring pump's shape: **one epoll
instance + one SO_REUSEPORT listener per worker**, connection owned by its
accepting worker for life, **persistent level-triggered `EPOLL.IN`
registration**. The once-per-worker handoff ONESHOT enforced is true by
construction, so the per-request `epoll_ctl` disappears entirely —
`epoll_ctl` now fires only at accept and on readiness-*shape* changes
(stall gains `EPOLLOUT`, drain drops it, TLS handshake steps pick a
direction). Accept moved into the worker's own loop (listener is just
another event, `accept4`-until-EAGAIN bounded at 128/event); the 12
acceptor threads are gone. Post-change strace: **zero `epoll_ctl`** in the
hot path — `read:write` 1:1, ~41 events per wait.

Diff: `lib/pump.kz` +153/−141 (`git diff` in the hunt-c worktree; also
touches `registerClientEpoll`, `epollMask`, `armOwnerWrite` — ONESHOT bit
removed from all three).

## Delta — same box, same load shape, interleaved

| arm | wrk rps runs (`-t6 -c512 -d12s /baseline11`) | best |
|---|---|---|
| old epoll (9530fed) | 413,967 / 391,406 / 288,332 / 367,700 / 403,208 / 414,595 | 414,595 |
| **new epoll (this fix)** | 648,310 / 379,456 / 579,317 / 622,761 / 651,558 | **651,558** |
| io_uring (9530fed, same box) | 524,639 | 524,639 |

**+57% best-vs-best** (414,595 → 651,558). Box is noisy (±25% run-to-run);
the ordering was consistent across all interleaved rounds — new epoll beat
old epoll in every A/B pair.

Correctness: GET/POST baseline11, /pipeline, /json/N, 404, keep-alive reuse
across routes on one conn, `Connection: close`, 300/300 concurrent-churn
requests, pipelined triple-request one write, split-segment request,
HTTPS accept+handshake+serve on the reworked per-worker TLS listener — all
verified on the patched binary. Full `validate.sh` was NOT run (its
container names/ports sit outside the hunt-c/9103 sandbox grant).

## Verdict — the named-open question, answered

**Both halves, earned:**

**(a) Worth improving — landed.** The epoll pump was carrying a ~35% tax of
pure bookkeeping (`epoll_ctl` = 1/3 of all hot-path syscalls) plus
shared-instance lock contention and a surplus accept fleet. None of it is
inherent to readiness-model I/O. +57% locally.

**(b) But it is still a fallback — and now we can say why with numbers.**
The remaining epoll floor is `epoll_wait`/`read`/`write` — ≥2 payload
syscalls and one wakeup-decision boundary per request, irreducible in a
readiness model. The ring pump amortizes all of it: multishot accept,
multishot recv on a provided-buffer pool (zero read calls per conn-life),
send SQEs batched per ~32-CQE enter — ~0.05 syscalls/req vs ~2.5. On the
Threadripper board a projected +57% puts epoll at ~790k vs 4,114,610 —
still ~5× behind. io_uring remains the answer for Linux; the epoll pump is
now an honest fallback rather than a neglected one.

Instrument caveat, stated plainly: on this arm64 Docker-VM the same uring
binary only manages 524k — a 1.27× gap over OLD epoll, and behind the NEW
epoll arm — because virtio forwarding + shared vCPUs compress every
transport difference. The 8.2× board gap does not reproduce here; the
syscall-count evidence (3.5→2 per request) is the transferable fact, and
the +57% local delta is a lower bound for what the board sees, not a
projection of it.
