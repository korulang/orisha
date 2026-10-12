# a faster encoder can lose to a tighter one

The compressor is not judged on encode time alone. The wire meters
every byte the encoder emits, and the sender pays for all of them.

Ported zix's `flate_fast` (greedy LZ, fixed-Huffman, one block,
threadlocal hash table, no stream state) into `lib/httparena.kz` to
chase the json-comp profile. The mechanism is real: it encodes faster
than driving zlib at Z_BEST_SPEED, and removing its per-call 16 KiB
table memset (epoch-tagged slots instead of a clear) made it faster
still. None of it won. Two interleaved races on the json-compressed
shape (arm64, io_uring, ~1M req/s of ~5 KB bodies) had the zlib arm
ahead in nearly every round — the fixed codes emit ~17% more wire
bytes on repeated-key JSON than zlib's dynamic blocks, and at this
request rate the extra bytes cost more than the encode saves.

The belief this corrects: "the winner's encoder is fast, so matching
its speed matches its throughput." Encode speed is half the price;
the other half is how big the output is, because output bytes are
send bytes. An optimization that trades ratio for speed can be a
regression wearing a benchmark-friendly disguise.

The encoder still earned its keep exactly where the trade doesn't
apply: freestanding has no zlib to cImport, so `flate_fast` is the
unikernel's only compressor — identity responses became real gzip.

2026-10-12 update — the trade moved inside our own codec and the
constants changed. `std/compress` now owns both ends of the dial:
`gzipInto` (dynamic, 1766B on the arena body, ~15µs) and
`gzipIntoFast` (fixed, single-pass, 2223B, ~6.9µs). The original
race priced *our* fixed against *zlib's* dynamic with a ~17% byte
gap; the in-house matchup has a ~26% byte gap against an ~8µs encode
saving. A same-box c256 A/B on the current send path leaned fast
(+5-12%, noisy) — the opposite direction of the high-rate result.
The belief survives as *regime-dependent*, not universal: under-
saturated send paths pay the encode, saturated ones pay the bytes.
The open question narrows to which regime the board's rate sits in —
that is a droplet measurement, not a principle.

## Related

- frag-serialize-the-invariant-render-the-variant — the sibling belief
  about where per-request work belongs.
- frag-small-segments-copy-faster-than-scatter — same lesson on the
  send side: byte count and call count are both costs, and profiles
  decide which one dominates.
