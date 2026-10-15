---
type: belief
id: frag-a-host-cap-is-a-site-property
provenance: korulang.org's reactor crossed Vercel's 100MB upload cap carrying
  identity+gzip per route; the first fix baked gzip-only for every consumer
  and was ruled wrong — the cap is Vercel's, not the library's. Measured live
  2026-10-15: gzip-only bake halves the reactor and the negotiated default
  stays for everyone else
ts: 2026-10-15
---

# A host cap is a site property, not a library policy (belief)

When korulang.org's embedded reactor crossed Vercel's 100MB single-file
upload cap, the tempting fix was to drop the identity representation for
every `~orisha:static` consumer — one body per route halves the embed.
That is the wrong scope: the cap belongs to *a host*, and the site that
deploys there is the party that accepts the trade. A library-wide bake
policy turns one site's constraint into every consumer's contract —
protocol negotiation quietly deleted for sites that never had the cap.

The shape that landed instead: `gzip_only` is an optional arg on the
`~orisha:static` *declaration*. Default keeps the negotiated pair —
identity + gzip, `Vary: Accept-Encoding`, per-representation strong etags.
A site that declares `gzip_only: true` bakes one representation per
compressible route and serves it whatever `Accept-Encoding` says — a
deliberate, declared protocol violation, scoped to the deploy that needs it.

The rule: **when a platform constraint is real, the lever lives on the
site's own declaration, not in the library default.** The library carries
both contracts; the site picks. Anything stronger smuggles a host's
limits into surfaces it never touched — and the next consumer on a
different host inherits a violation it never asked for.
