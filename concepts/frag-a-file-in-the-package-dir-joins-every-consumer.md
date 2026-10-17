---
type: belief
id: frag-a-file-in-the-package-dir-joins-every-consumer
provenance: lib/httparena.k's orisha:init (DATASET_PATH seed) loaded into
  every `import orisha` program — claimants and examples refused to start
  without the bench's dataset. Moved to httparena/handlers.k; the
  websocket claimant then emitted zero httparena symbols and closed 9/9
ts: 2026-10-15
---

# A file in the package dir joins every consumer's program

**Belief formed (2026-10-15):** a `.k` module sitting in a package's
mapped directory is not "near" the library — it IS the library.
Impl resolution loads across the package, so `lib/httparena.k`'s
`orisha:init =` (the HttpArena dataset seed) became every consumer's
init: any server that wrote `import orisha` refused to start without
`DATASET_PATH`. Claimants, examples, static sites — all of them.

The README's own hedge ("not part of the public Orisha API") was
true of spelling and false of consequence: the file's *name* wasn't
public, but its impls ran in every program. Blast radius of
placement = the import surface of the package, not the intent of
the author.

The rule that generalizes: app code — benchmarks, examples,
claimants — belongs beside its own `main.k` under its own paths
mapping. The import path it earns there (`httparena/handlers`)
honestly names what it is: the app's module, not the framework's.
When a file "needs" to live inside another package to get a name,
that name is the bug — the file wanted to be its own package.

Adjacent hazard, worth one line: a `package/file` import whose file
stem equals the package name (`httparena/httparena`) emits nested
`koru_X.koru_X` in Zig — ambiguous references. Stutters break; name
the module after its job (`handlers`), not its package.
