# SIGPIPE is death, not an I/O error

**Belief:** a peer that closes mid-response is handled by the write path —
`send`/`write`/`SSL_write` return an error, the loop closes the connection,
life goes on.

**Correction (2026-10-05):** on POSIX the default action for SIGPIPE is
*terminate the process*. A `send(fd, …, 0)` to a peer-closed socket never
returns the error — it raises the signal, and the server vanishes with an
empty log. Measured on once-campfire-koru: a 1500-way curl storm killed the
server silently every time, zero diagnostics.

**The contract:** any keep-alive server must disarm SIGPIPE once, before the
first write — `sigaction(SIGPIPE, SIG_IGN)` at the top of every pump `drive`
body — after which writes return `EPIPE` and the existing error path owns
peer-close. This is a *pump* obligation, not an app one: the app cannot
express it, and leaving it unset means load testing measures process death,
not serving.

**Open:** the residual ~0.10% non-2xx under concurrency is a separate defect —
mangled request paths (404/302 on `GET /up`) consistent with fd reuse racing
the global `conn_states` table across per-worker ownership. SIGPIPE explained
the *death*, not the *desync*.
