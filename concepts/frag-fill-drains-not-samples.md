---
type: belief
id: frag-fill-drains-not-samples
provenance: epoll pump TLS chunked-echo hang, 2026-10 — verify on Linux 6.8 (httparena validate.sh 48/48, POST /echo chunked 102400B over TLS)
ts: 2026-10-31
---

# `fill` drains its transport, not samples it (belief)

One `SSL_read` delivers at most one TLS record (~16KiB plaintext). A fill
that stops at the first successful read leaves the rest of a flight inside
OpenSSL's decrypted-but-undelivered buffer: the socket reads empty, no new
readiness event ever fires, and the conn parks mid-request holding bytes
it will never see. The `.more`/`.idle`/`.gone` contract means "did any
bytes land this call" — it does NOT mean "the transport is drained." Every
fill variant must therefore loop its read until the transport says
`WANT_READ` (TLS) or `WouldBlock` (plaintext), not return after the first
good read.

## The shape that fell out

- The trap is invisible to readiness: EPOLLIN watches the *socket*, not
  OpenSSL's internal buffer. After the socket drains, pending plaintext
  produces no further events — the parked conn looks "waiting" forever.
- Content-Length bodies masked the defect: a declared `take` keeps the
  conn reading until bytes arrive. Chunked bodies have no declared
  length, so the park after an incomplete `chunkedMessageLen` walk was
  permanent — `0\r\n\r\n` sat inside OpenSSL while the parse waited for
  the wire.
- Buffer growth belongs *inside* the drain loop: a full `st.buf` handed
  to `SSL_read` is a zero-length window — OpenSSL returns an error and
  the conn dies mid-body. Grow before every read, not once before the
  first.
- Plaintext's `posix.read` per event shares the same contract — a conn
  whose request straddles two TCP segments needs every arrival to drain
  the socket fully, not one read's worth.

## Open questions

- Fairness under sustained pipelined input: a conn that never stops
  arriving could starve the worker's other conns if the drain is
  unbounded. The current fix loops until `WANT_READ` — bounded by
  OpenSSL's buffered plaintext, not the socket. A fairness cap (e.g.,
  drain N records then yield) may belong here if a pathological conn
  ever shows up in the profile.
