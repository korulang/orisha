---
type: belief
id: frag-freshness-is-a-counter-the-writer-bumps
provenance: page cache work, 2026-10 — Campfire room_show needed
  Rails-style cached pages without the cache ever guessing at staleness
ts: 2026-10-12
---

# Freshness is a counter the writer bumps (belief)

A response cache cannot know which writes matter — only the writer can.
So the ledger is a single monotonic generation: `generation-bump` is the
writer's signal that rendered output may now differ, and every stored
entry carries the generation it was rendered under. A lookup compares
stamps and skips what a bump retired; the next store frees it. Nothing
serves across a bump, and nothing is invalidated by a TTL's guess.

The split of responsibility is the claim: the cache keeps the ledger but
never predicts freshness — predicting is heuristics, and heuristics serve
stale pages some of the time, which is a correctness bug with good
latency. The app owns the semantic ("a committed message changes these
pages") and pays one atomic increment per commit; the cache owns the
mechanics (keying, storing, retiring) and asks nothing else of the app.

Sibling of `frag-the-producer-vouches-what-it-knows`: `cacheable` is the
producer's voucher that a response depends only on the key inputs and the
current generation; this belief is the counter that gives the voucher a
clock to be vouched against.
