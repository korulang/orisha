# Small segments copy faster than scatter

**Belief tested (2026-10-11):** sending a response's segments as `writev`
iovecs — pointing the kernel at the original memory instead of memcpy'ing
into `send_buf` — is faster than the copy. True for large segments, **false
for small ones**, and the crossover is not subtle.

**The measurement:** io_uring pump, `/pipeline` (91-byte rodata head + 29-byte
Date pin + head tail, ~8 responses per send window ≈ 24 iovecs per SQE),
exclusive :8080, interleaved gcannon -c400 -t4 -d4 -p8, 4 pairs: scatter-send
lost 3 of 4, **~11% down** (5.1M vs 5.8M req/s, all-2xx both arms). Gated at
`SCATTER_MIN = 4096` the same binary returned to parity.

**Why it loses:** the saved copy is ~150 bytes of L1-hot data — nearly free —
while the cost added is per-window iovec materialization plus the kernel's
iov import: the send path walks ~24 tiny vectors at ~24 scattered addresses
inside io_uring submit/execute, where the flat path imports one contiguous
span. Scatter-gather is not "free zero-copy"; it moves the copy loop into the
kernel and makes it walk a pointer table to do it.

**The ruling:** scatter-send is a size-gated optimization, not a mode. Engage
iov only for segments large enough that skipping the copy amortizes the
pointer walk — `SCATTER_MIN` is set to a page; the honest crossover probably
sits between a few hundred bytes and there, and re-measuring it belongs to
whoever has a real large-static-segment workload (sendfile-class bodies,
cached asset serving). Below the gate the flat `send_buf` path is *already*
the zero-copy-where-it-matters design: `ringRenderTarget` composes into the
send buffer so the expensive copy never exists.

**Corollary for the toolbox:** a perf idea that wins by "avoiding a copy"
needs the copy's size priced first. Under ~a page, copying is the cheap end
of the trade.

**Attribution caution from the same run:** every throughput reading taken on
this container before 2026-10-11 was REUSEPORT-blended — a stale `/app/a.out`
(Oct-08 build, PID 28) held :8080 with 4 sockets in the same reuse group as
every test binary. Directional deltas survived (blending dampens, does not
flip); absolute numbers were diluted ~2x toward the old binary. The check
that belongs in every benchmark session: `grep -c " 00000000:1F90 "
/proc/net/tcp` must equal the *current* binary's worker count, not merely be
nonzero.
