---
type: belief
id: frag-marks-ride-the-compilers-channel
provenance: marks migration 2026-10 — koru merge `9f1dadf12` moved the transform
  runner's handled-witness from `.annotations` to `.marks`; orisha's router was
  an out-of-tree consumer the merge could not see
ts: 2026-10-10
---

# Transform marks ride the compiler's channel, never user annotations (belief)

Orisha's router transform is a downstream author on koru's marks contract,
ruled upstream in
`concepts/frag-the-at-namespace-is-the-compilers-side-channel.md` (koru):
compiler-internal `@...` strings — `@pass_ran` here — live on the invocation's
`.marks`, and `.annotations` belongs to user-authored annotation text alone.
This is not a new spelling; it is a ruled channel consumed from outside the
repo that rules it.

## What the violation taught

The marks merge changed the runner's read side and migrated every producer it
could see — koru_std plus the in-repo tests. Orisha sat outside that horizon,
still reading and stamping `@pass_ran` on `.annotations`. Every kept-path
invocation then re-ran the transform until `TransformDidNotReplace` — the
entire `350_*` router cluster red at once, eleven tests, one mechanism. The
channel change is an ecosystem break by construction: there is no deprecation
shim, because the runner cannot read the old field without un-deciding the
ruling.

## The rule this file lands

When koru's marks architecture moves, every file in this tree that reads or
writes `@`-prefixed marker strings on AST nodes moves with it — read side and
write side together, annotations passed through untouched. A green board that
never exercised a kept-path invocation says nothing; the drift is silent
wherever the path changes.
