---
challenge: workhorse-corpus
kind: frame
status: standing
yields: one runnable pure-Koru example, or one pinned framework gap
family: capability
---

# Challenge 002 — the workhorse corpus

*Walker context — the recurrence that earned this frame. Writing the HttpArena
entry in pure Koru required inventing four pieces of surface that did not
exist: `orisha:body`, `orisha:query`, `std/fs:read`, `std/string:detach`. Every
honest workload is a probe into what the framework can't yet spell — and the
ones that do spell become runnable proof. This is `koru/challenges/004`
(kernel gap mining) transplanted to the framework's domain: workloads as
instruments, never a scoreboard.*

---

## The brief (sealed — you are the contestant)

Pick ONE real web workload and write it in pure Koru on Orisha. The workload
choice is the variance — read `examples/` and this catalog first, and bring
something not already there. Suggestions as a starting shelf, not a menu to
copy: SSE fan-out, multipart upload, a reverse proxy, a file server with
`Range` support, cookie sessions, a URL shortener, a rate limiter, WebSocket
echo, a template-rendered page, a JSON API with real input validation.

The rules that make an artifact count:

- **Pure Koru, no Zig in the workload.** The example's `.k` files carry all
  the logic. If the workload needs surface that doesn't exist, the *correct*
  yield is the named gap — grow `lib/` or `std/` primitives if that's the
  honest fix, but a bespoke `~proc` doing the workload's thinking is fraud.
- **Do not invent syntax.** Ground every construct in a passing
  `koru/tests/regression/**` test or an existing green example. An
  unspellable construct is a language gap — name it, don't guess it.
- **Green means served.** The example compiles through `koruc` and answers
  real requests correctly — not "it built." Run it, hit it, show the wire.
- **A gap is a first-class artifact.** If the workload can't be written
  honestly, pin it: a minimal repro plus the compiler diagnostic or the
  missing-surface description, filed as a catalog entry flagged `gap`.

## Done-gates (self-check before judging)

1. For a green yield: the example compiles, serves, and is exercised live;
   it lives self-contained in `examples/<name>/`.
2. For a gap yield: the repro is minimal, the refusal or missing surface is
   named precisely, and it sits in `challenges/catalog/gap-<slug>.md` with
   the workload that found it.
3. The catalog entry exists either way — `challenges/catalog/<slug>.md`
   naming the workload, the outcome, and what it proved about the surface.

## The catalog

`challenges/catalog/` — runnable examples and pinned gaps, not prose. A gap
that later gets closed doesn't get deleted: it gets marked closed with the
commit that closed it, so the corpus keeps the history of what the framework
couldn't say and when it learned.
