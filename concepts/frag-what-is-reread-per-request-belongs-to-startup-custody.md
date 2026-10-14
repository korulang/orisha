---
type: belief
id: frag-what-is-reread-per-request-belongs-to-startup-custody
provenance: orisha challenge 001, hunt-d — the pure-Koru httparena handler re-read and re-parsed dataset.json on every /json request (~13k rps); moving the file into std/store custody at init measured ~240–270k rps on the same box, byte-faithful
ts: 2026-10-15
---

# What is re-read per request belongs to startup custody, not the handler path (belief)

The honest pure-Koru handler read the dataset file, parsed it, rendered, and
freed — per request. That was ~90% of the `/json` cost and it was not a
handler bug: *no surface existed to do it once*. The handler had only
per-request scope, so "load once, serve views" was unspellable without an
escape hatch.

The missing surface was lifecycle, not caching: `orisha:init` — an abstract
tor the app implements once, run in `serve` *before* workers spawn. Because
it runs before worker threads exist, custody it seeds (`std/store` rows,
rendered fragments) becomes visible to every worker through thread-spawn
ordering — immutable thereafter, no lock, no copy. `| failed` refuses startup
rather than serving a partial view, and the failure is the first line of
logs, not the millionth request.

Measured on the same box, same load: `/json/50?m=2` went ~13k → ~270k req/s
on the merged tree, with the response bytes unchanged — the cost was
materialization timing, not rendering.

## What follows

- The per-request reread is a *shape* the framework makes spellable, not a
  sin the handler commits: if "once" has no home, "every time" is the only
  spelling. Audit any handler loop for file/parse/render work that could be
  moved to `init`.
- The mechanism generalizes past benchmarks: any immutable-after-start
  dataset (routing tables, templates, seed data) wants the same custody.
- Related: [[frag-serialize-the-invariant-render-the-variant]] — the dataset's
  wire fragments are rendered once at init and only the variant (count,
  multiplier) is rendered per request.
