---
type: belief
id: frag-a-target-nobody-builds-rots
provenance: unikraft target rot discovered 2026-10-12 (three independent
  breaks between 2026-08-09 and first rebuild); evolved 2026-10-27 when
  the same rot reached the httparena entry against deliberate contract
  walls — uncompiled consumer, not unbuilt target
ts: 2026-10-27
---

# A target nobody builds rots

**Belief.** A supported build target that no check compiles is not
supported — it is broken, and the only question is when someone
notices. The break is silent because the rot arrives inside unrelated
work: every commit that lands is green on every target that IS built,
and the unbuilt one's failure never reaches an exit code.

## Evidence

`--build=unikraft` produced a serving Unikraft image on 2026-08-09
(see `examples/unikernel`). Between then and 2026-10-12, three
independent changes broke it, each correct on every target the board
builds:

- The once-per-wakeup Date stamp made pump code reach
  `@import("root").koru_orisha` — true on hosted builds where the
  emitted file IS root, false under a freestanding wrapper where root
  is the wrapper. `wrapper.zig` had to re-export the module surface.
- The kTLS-era conn-state machinery brought ~40
  `std.heap.c_allocator` sites. libc's malloc does not exist on
  freestanding — one `ukAdmit` deinit was enough to kill the link.
- The uk pump's `poll` extern needed `CONFIG_LIBPOSIX_POLL`, which the
  Kraftfile never declared.

None of these was a bug on Linux. The unikernel's failure mode is the
same class as a test suite that isn't run: the artifact claims support
and the claim is stale.

The same rot reached the *application* layer on 2026-10-27: the
HttpArena entry (`httparena/main.k` + `handlers.k`) refused to
compile, 14 days after its last board build — against two deliberate
contract walls, not accidents. `fmt:ln`'s `.text` became
`scratch@scoped` (koru c3750391, 2026-10-17 — `respond-int` could no
longer produce it into the Response record) and
`std/string:parse-int` tightened to the slice, not the wrapper. The
toolchain did nothing wrong anywhere; the consumer broke anyway. So
the rot class is wider than "unbuilt target": it is "uncompiled
consumer" — and the clock is contract-velocity, which includes
deliberate improvement, not just bit-rot.

## The seam that holds

The fix shape the codebase already teaches: a comptime target switch
at the point of need, not a fork of the file. `pumpAlloc()` returns
`std.heap.c_allocator` on hosted and a fixed image arena on
freestanding — one line of comptime-eliminated branch per site, zero
hosted cost. `SendMutex` degrades to a no-op struct the same way;
`requestAllocator` swaps page allocator for fixed arena the same way.
The dataset the json route reads from disk is `@embedFile`'d on
freestanding — one less machine to ask.

`~proc` bodies splice into callers, so module-scope names are illegal
bare inside them (`KORU112`): `$mod.pumpAlloc()` is the spelling that
survives the splice.

## Open questions

- Whether `--build=unikraft` belongs in a check so the next break is
  loud — the examples exist, the toolchain is installed wherever
  kraft+qemu live, and a compile (not a boot) catches everything seen
  here.
- Whether gzip should get a pure-Zig deflate (`std.compress.flate`)
  on freestanding — identity is legal HTTP, but it makes the unikernel
  json-comp response a different wire than hosted.
