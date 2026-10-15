---
cost: gzip-allocator-pairing
organ: stdlib
status: closed
closed-by: uncommitted koru_std/compress.kz change, 2026-10-14 session
---

# gzip allocator pairing

**Cost:** `std/compress:gzip` allocated its output with
`std.heap.page_allocator`, but Orisha frees `body_allocated` response bodies
through `koru_allocator()`. On Linux/glibc: `free(): invalid pointer` at
`/json/50` + `Accept-Encoding: gzip`. Silent on darwin — glibc caught it.

**Fix:** gzip allocates/reallocs/frees through `koru_allocator()` on hosted
targets; the freestanding gate keeps pointing at `gzipInto`.

**Evidence:** `free(): invalid pointer` reproduced in the Linux image,
`json-comp` 500'd under gzip; after the fix `validate.sh` reports
`json-comp` green and the process survives teardown. Found only because the
pure-Koru path actually exercises the primitive — the Zig handlers never
called it.
