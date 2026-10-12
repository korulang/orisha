# the trailer cost more than the codec

A gzip member is three parts: header, deflate body, CRC trailer. We spent
three races optimizing the middle while the trailer quietly out-cost it.

The evidence chain, honestly ordered: the dynamic-Huffman encoder lost to
zlib ~30% end-to-end, and every intra-encoder optimization (amortized
tree, mask coverage guard, distance table) closed it only to ~15-25%.
The component bench answered in one run what the server races could not
isolate: `std.hash.Crc32.hash` — a byte-at-a-time table walk — took 21µs
of the encoder's 29µs on an 8KB body. The codec itself was 8µs. zlib's
14.5µs includes its own hardware CRC; ours wrapped a world-class match
in a reference-grade checksum.

Swapping the byte-table walk for a slicing-by-8 table took the call
to 12.6µs — faster than zlib, with tighter output. The interleaved
race flipped: the owned encoder won 4/6 rounds, +9% on totals.

Correction (2026-10-12): an earlier draft of this frag credited ARM
`crc32x` inline asm. That arm never ran anywhere — every build that
produced the 12.6µs number resolved `ff_hw_crc` false (baseline cpu
targets don't advertise `.crc`), and on native aarch64 the spelling
doesn't compile at all: Zig's `r` constraint binds GPR64, `crc32x`
needs w-registers, and 0.15.2's asm grammar has no width modifier.
The win was slicing-by-8 alone, on every target, from the start.
The arm was removed when the encoder lifted into `std/compress`.

Second correction, same day (2026-10-12): pmull folding is no longer
unbuilt — it landed and it was the last reason zlib won anywhere. A
component race after multi-block showed the owned encoder slower on
15-80KB compressible bodies (0.8-0.9x); the per-KB CRC table walk
(0.44µs/KB, ~19% of the call at 81KB) was again the whole deficit.
`pmull`/`pmull2` DO compile under Zig's `w` constraint (SIMD regs) —
only the scalar crc32x accumulator was unspellable. The Gopal/Ozturk
fold via Chromium's constants, bitwise-verified against the table
path across ~2700 sizes: 0.44µs/KB -> 0.03µs/KB. Re-raced per call,
the owned encoder now beats zlib on every shape measured (1.02x on
81KB compressible, 1.9x at 1.8KB, 3.4x on repetitive 1MB) with
tighter output on all of them. x86 PCLMUL remains unbuilt — on
non-aes targets the trailer still walks the table.

Two beliefs this hardens. The world model's cheapest instrument is the
one that isolates the claim: end-to-end races can rank two systems but
cannot say *where* the delta lives — a 10-line bench loop timed the
offender in seconds. And "our own code" is not where our cost lives;
a single stdlib call outside the optimized region can be most of it.
Profile the boundary, not just the algorithm.

## Related

- frag-a-faster-encoder-can-lose-to-a-tighter-one — the sibling belief
  this arc started with: wire bytes are a cost too. Both are true now;
  the encoder that wins is tighter AND faster because the loss was
  never in the codec.
- frag-serialize-the-invariant-render-the-variant — the cached tree is
  the same move: amortize the shape, render the bytes.
