# The conn lifecycle is a serial seam

**Belief formed (2026-10-12):** on a churn profile — thousands of live
connections cycling every `-r` window — the winner is decided at the
connection seam (accept, register, dispatch, release), not inside the
request path. Any serialization there is a hard cap, not a tax.

Two seams were instrumented and found in the epoll pump. The fd→ConnState
table's single global mutex was taken on *every event dispatch* — not for
correctness of dispatch (ONESHOT already guarantees a single owner) but
because the event carried only a descriptor and the pointer had to be
recovered through a table. And accept was one thread paying the whole
register cost per conn — a serial path whose per-conn time caps the
churn rate a `-r`-limited profile demands at ~requests-per-second over
requests-per-conn.

The removals share a shape: `epoll_event.data` is a union and can carry
the `*ConnState` itself, so dispatch needs no lookup at all — the table
survives only where a conn must be *named by fd* from another thread
(`wsSendFd`, io_uring's `connIsWs`). And REUSEPORT gives each acceptor
its own listener so the kernel hashes flows and the register path runs
in parallel; `accept4(NONBLOCK|CLOEXEC)` retires the fcntl pair on the
same pass.

The honest caveat: the instrumented box cannot resolve the delta —
interleaved A/B between the table and pointer builds sits inside the
box's noise. These are mechanism fixes (strictly less serialized work
per event and per conn), not locally measured wins. Whether they move
the board is a droplet measurement.

## Related

- frag-deferred-send-makes-close-a-drain — the sibling conn-lifecycle
  belief on the teardown side.
