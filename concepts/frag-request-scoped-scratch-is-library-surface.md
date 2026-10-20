---
type: belief
id: frag-request-scoped-scratch-is-library-surface
provenance: once-campfire-koru's pages module + session threadlocals
  upstreamed into orisha/ctx, 2026-10-17; committed 2026-10-20
ts: 2026-10-20
---

# Request-scoped scratch is library surface (belief)

Two app-side inventions kept reappearing in consumers: a cell to carry a
value out of a `! row` arm into the `| done` continuation (the arm fires
per row and cannot produce the enclosing tor's terminal), and a buffer
to fold per-row fragments into the one response body. Campfire spelled
both itself — `pages:` for the body, threadlocals in session/index.kz
for the cells. Orisha now owns both as `orisha/ctx`: named cells
(`set-int`/`take-int-or`/`set-text`/`take-text`/`clear`) and the body
accumulator (`begin`/`body-write`/`body-take`/`frag-write`/`frag-take`).

The ruling: this is orisha's contract because the safety argument is
orisha's, not the app's. The cells and buffers are threadlocal in the
companion; they are request-scoped only because an orisha worker is
single-threaded and a handler runs to completion. An app spelling this
itself re-derives the pump's threading model — exactly the knowledge app
code should not have to encode. Sibling of
frag-arms-hand-what-outlives-them: same boundary question (what survives
the arm), narrower answer (values, not work).

Spelling ruled: the module is `orisha/ctx`; the cell verbs are
`set-int`/`int`/`int-or`/`take-int`/`take-int-or`/`set-text`/`text`/
`take-text`/`clear` and the body verbs are `begin`/`body-write`/
`body-take`/`body-status`/`frag-write`/`frag-take` — `take-*` clears,
`begin` does not clear cells, `set-text` answers `| ok` / `| truncated`.

Contract notes a consumer must know: cell names are looked up per call
over a small fixed table — collisions across an app's modules share a
cell, so names are per-purpose ("session.uid", not "uid"). Text cells
cap at 2048 bytes; overflow answers `| truncated`, never a silent chop.
`take-*` clears; `begin` does NOT clear cells — a csrf stash primed
before the first begin must survive it.

Open: if a handler ever interleaves mid-request on one worker, the
request-scope argument breaks and the cells must move into an explicit
request record. ctx.k's header records the same warning.
