---
type: belief
id: frag-an-early-packet-is-a-deferral-not-a-drop
provenance: measured on the h3 QUIC pump (h2load -c1 -m64 qlog) —
  the client's coalesced first 1-RTT packet was dropped by the
  long-header walk; ngtcp2 cubic clamped its cwnd to ~5.1KB for the
  whole run, and the fix restored it
ts: 2026-10-31
---

# an early packet is a deferral, not a drop

A packet that cannot be processed *yet* is not a packet that cannot be
processed. When the receive path meets input ahead of its own readiness —
a 1-RTT datagram before app keys yield, a coalesced short-header tail behind
the handshake flight — dropping it converts a timing artifact into a wire
signal: the peer's loss detector fires, congestion control halves the window,
and the connection's throughput ceiling is set by that spurious event for
its whole life.

Measured 2026-10-31 (h2load -c1 -m64, baseline2, orisha-m1): the client's
first 1-RTT packet rode coalesced behind the Finished flight; the
long-header walk stopped at it and the early-dgram path had no pre-key
holding. One packet lost at t=4ms → ngtcp2 cubic cwnd 13200→5094 and flat
for 8s → one datagram in flight → 25–77k req/s run-to-run, bimodal.
Buffering the bounded early set and processing the coalesced tail made the
loss disappear; ~140k req/s every window.

The rule: the drop decision belongs to the *decrypt* step, not the
*readiness* step. Anything undecryptable is dropped (forgery indistinguishable
from loss); anything merely early is held against a bounded buffer, and the
bound is the honest escape — overflow drops, but the common case is one
flight, not a flood.
