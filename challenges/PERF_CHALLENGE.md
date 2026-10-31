---
challenge: perf
kind: generator
status: standing
yields: one verified throughput improvement on the H3/io-uring path
catalog: ../perf
created: 2026-10-31
---

*Walker context: orisha's h3 lane is validator-green but behind the field
(baseline ~2.3x, static ~8x vs agensio at last honest measurement, on
Hetzner cax31). A standing generator producing one measured optimization
per replay; the catalog records each accepted change with its verified
delta and commit.*

---

## The brief (sealed — you are the contestant)

You are the contestant. You do not ask which direction. Pick ONE
optimization, ship it, prove it.

Ground truth: `lib/pump.quic.kz` and `lib/index.kz` in this worktree,
branch `h3/quic` (HEAD ~5728e69). The server is the HttpArena image:
build with `docker build -f /tmp/h3ctx/Dockerfile -t httparena-orisha-uring /tmp/h3ctx`.

The catalog (`perf/`) records what was already taken. Read it first;
bring something not already there. Variance across replays is the
metric — a second contestant with the same idea is a wasted replay.

Candidate territory (non-exhaustive — pick one or name your own):
- per-packet AES key expansion (`AesHp.initEnc`, `AesGcm.encrypt` key
  schedule per call) — cache expanded contexts in `QKeys`
- per-packet `ArrayList` allocation in `quicBuildPacket` — frames/hdr/
  payload lists re-allocated every packet
- `quicOnAck` / sent-record scans per client ACK
- stream-map iteration per packet in the new-data loop
- datagram batching/GSO (`sendmmsg`, `UDP_SEGMENT`)
- ACK emit strategy vs ngtcp2's (`/tmp/h3ctx/ngtcp2` is on disk —
  read it, don't guess)

Rules — all hard gates, no exceptions:

1. The full HttpArena validator must pass 80/0 on an image built from
   your commit. This is the gate that cannot be waived.
2. You must produce before/after numbers YOURSELF: `-c1 -m64` on
   `/static/reset.css` and on `/baseline2`, plus the 4×64 race shape,
   same machine, same client (`h2load-h3:local`). Numbers you did not
   run are not numbers.
3. No commissioned hardware, no new tools, no ngtcp2/quiche *linked*
   (reading them is the point, linking them is not).
4. Commit in this repo's hook format (`## World Model`, `## Membrane`).
5. Your report is: what you changed (commit sha), the before/after
   numbers you ran, and where the delta went. Anything else is noise.

You ship when the gates pass. You are done when you report.
