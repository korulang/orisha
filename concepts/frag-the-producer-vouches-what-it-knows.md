---
type: belief
id: frag-the-producer-vouches-what-it-knows
provenance: HttpArena zix study, 2026-10 — answer's tail re-probed every
  response for facts the emitter had already computed at compile time
ts: 2026-10-11
---

# The producer vouches for what it knows (belief)

When the thing that emits a value already knows a fact about it, that fact
should arrive as a field on the value — not be re-derived by the consumer
probing the value. The `answer` tail ran three scans per request
(`startsWith "HTTP/1."`, `indexOfScalar '\r'`, `eql "Date: "`) to learn
what the route transform had already established at compile time: this
literal's `body` is a complete wire message, and the Date splices at a
known byte offset.

The mechanism is a voucher: `.wire` and `.wire_date_hole` ride the emitted
record; the tail takes the voucher branch and skips the probe. The probe
stays as the fallback for wire bodies the transform never saw — a handler
that hand-renders `"HTTP/1.1 ..."` still answers correctly, it just pays
the scan its spelling asked for.

Sibling of `frag-serialize-the-invariant-render-the-variant`: same root
claim (per-request re-derivation of compile-time-known facts is waste),
different surface. That one splits body bytes into prefix and live render;
this one carries facts *about* the bytes as record fields. Together they
name the general rule: the compiler's knowledge crosses the emit boundary
as data, never as work the runtime must redo.
