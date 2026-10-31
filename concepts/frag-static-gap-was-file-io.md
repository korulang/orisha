---
type: frag
id: frag-static-gap-was-file-io
provenance: h3/quic perf work
ts: 2026-10-31
---
The static-h3 throughput gap (~8x vs agensio on native Linux) is dominated
by serve-file doing a full per-request disk read — not by QUIC transport
pacing. Prior belief that the gap was transport-side (ACK cadence, PMTU,
batching) was wrong: each of those was fixed and the number did not move;
the file I/O fix moved it ~15x.

Ruling: a per-request cost this large belongs to the handler, not the
wire. Measure handler-side syscalls before diagnosing transport.
