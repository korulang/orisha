# Runtime reads beside the bake

**Belief:** Orisha content must exist at compile time; anything dynamic needs a
different server.

**Correction (2026-08-23):** the belief was too wide. What is true: *baked*
remains the right default for content known before the binary is built, and
`orisha:static` stays the zero-cost fast path. But `orisha/io` now provides
runtime reads (`load` → ready/gone/refused) with explicit caller ownership, so
Orisha is all-purpose without giving up the bake. The two are complements, not
rivals: the bake answers what compile time knew; io answers what the machine
knows now.

**Why the three branches matter:** gone (404) and refused (500-class) were
collapsed by every earlier stub surface on this machine, and collapsing them
is how serving bugs hide. A missing file and an unreadable file are different
facts.

**Freestanding targets:** no filesystem, so `io:load` refuses the build via
`@compileError`. Refusal at build time, never a runtime stub that returns
`refused` forever.

Open: streaming reads (unbounded sizes through the pump) do not exist yet;
`load` is whole-file into caller-owned memory.
