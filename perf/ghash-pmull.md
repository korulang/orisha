---
cost: GHASH runs bit-sliced software clmul on aese-capable aarch64
organ: lib/pump.quic.kz (HwGhash, HwAesGcm)
status: closed
---

# GHASH → pmull (arm64 HWCAP path)

## The cost

`std.crypto.onetimeauth.Ghash` picks its clmul backend comptime on
`builtin.cpu.has(.aarch64, .aes)` — the same detection gap C3 documented for
AES (zig 0.15.2 native CPU detection resolves 'generic' in this build VM).
`HwAesGcm` (C3) ran aese for the block cipher but paid ~20 vector ops per
carryless multiply for every tag — verified by disassembly: 20 pmull in the
merged binary, all inside `gzip_event.handler` (koru_std CRC fold), zero in
the GHASH path.

## The fix

`HwGhash` — a mirror of std's `Hash(.big, true)` (ghash_polyval.zig,
zig 0.15.2) with `clmul` pinned to `clmulPmull` (pmull/pmull2 under
`.arch_extension aes`, same trick as `HwAesBlock`). Wired into `HwAesGcm`.
The HWCAP oracle (`qkHwAes`) now requires HWCAP_AES|HWCAP_PMULL — a
PMULL-less part stays on std's soft path end to end.

## Measurements I ran

Microbench (host aarch64, `-mcpu=generic` to reproduce the VM's detection
gap, min of 15 reps, real pmull/aese execution — `p4-bench-crypto.zig`):

| payload+ad | soft GHASH | pmull GHASH | ratio |
|---:|---:|---:|---:|
| 64B   | 511 ns   | 104 ns   | 4.94x |
| 200B  | 987 ns   | 194 ns   | 5.09x |
| 512B  | 1815 ns  | 249 ns   | 7.29x |
| 1200B | 3896 ns  | 533 ns   | 7.30x |
| 1344B | 4168 ns  | 442 ns   | 9.43x |
| 4096B | 11934 ns | 1178 ns  | 10.13x |

Whole-op (AES-CTR + GHASH + tag) cost per packet-encrypt.

Disassembly: pmull count 20 → 210; new sites in `HwGhash.initForBlockCount`
(44) and `HwGhash.blocks` (134 across the 16/8/4/2/1 aggregation ladder)
plus inlined init in `gcmEncrypt`/`gcmDecrypt`.

E2E (h2load-h3 -t1 -c1 -m64 -D10, interleaved m1/p4 x3, docker bridge —
see caveat): ~30-60 req/s on both arms, indistinguishable. Race shape
(-t4 -c64 -m64 -D10): m1 2527, p4 2267 (one rep, noise-level). The e2e
shape can't resolve this delta: h2load+orisha QUIC churns the connection
after each ~64-request burst (reproduces on the pre-contest baseline image
`orisha-baseline-5728e69` — pre-existing, not from C1-C4), capping
throughput ~2000x below the pipelined rate where GHASH is hot. Reported
honestly: the instrument that sees the delta is the crypto microbench.

Correctness: `zig test` on host aarch64 — HwGhash byte-identical to std
Ghash for all lengths 0..4096 plus split-update/pad streams; HwAesGcm
byte-identical to `std.crypto.aead.aes_gcm.Aes128Gcm` across 90
(msg,ad) shapes and the NIST GCM known-answer vector
(key=0,iv=0 → 0388dace…/ab6e47d4…). Validator: see commit message.
