# Deferred send makes close a drain, not a switch

**Belief formed (2026-10-08):** on a completion-driven pump, a connection's
response is a *future*, not bytes already on the wire — and `shutdown()` at
`reply` time is a bug, not a fast close.

The old contract assumed replies were synchronous: `posix.write` inside the
handler put bytes in the kernel before `reply` returned, so a `Connection:
close` could safely `shutdown(SHUT_RDWR)` the moment the handler finished —
the FIN followed data already queued. On the io_uring pump the handler's
write only *stages* bytes into `send_buf`; the send SQE submits at the next
advance. `shutdown(SHUT_WR)` in between makes that SQE fail with EPIPE and
the response never leaves — measured as "empty reply from server" on every
`Connection: close`, cleartext and TLS alike.

**The rule that makes it safe:** on a ring conn, `close` is expressed as
`ring_dead` and the pump drains — staged bytes go out as the send SQE, the
CQE lands, and only then does teardown `shutdown`+`close`. TLS close_notify
rides the same drain: `SSL_shutdown` emits to wbio, wbio stages into the
wire queue, the send SQE carries it. Close is an ordering property of the
drain path, never an extra syscall beside it.

**Where it bit:** `reply`'s `!keep_alive` leg called `shutdownConn`
unconditionally — correct on readiness pumps (bytes already written), wrong
on the ring (bytes staged). The tell was `pendingLen(st) == 0` looking like
"nothing in flight" when everything was in flight, one buffer over.

Open: ws-close and hang-up take the same shape and were left on the
shared `shutdownConn` path — fine on readiness pumps; if a ws conn on the
ring ever needs an abrupt close it must route through `ring_dead` too.
