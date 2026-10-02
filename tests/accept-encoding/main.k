// Accept-Encoding negotiation probe — nested static-router under a router.
//
//   ! [GET /api/health]  → dynamic route (router must still dispatch it)
//   ! [*]                → static with SPA fallback, gzip-gated on the request
//
// Build & run:  koruc main.k && ./a.out
// Verify:       zig test generated/site_routes.zig   (emitted by the transform)
//               curl -H 'Accept-Encoding: gzip' -D- http://localhost:3101/
//               curl -D- http://localhost:3101/any-missing-path  (fallback)

import orisha

orisha:static(name: "site", root: "public", fallback: "index.html")

orisha:handler = orisha:router(req)
! [GET /api/health] -> { status: 200, body: "{\"status\":\"ok\"}", content_type: "application/json" }
! [*] |> orisha:static-router(name: "site")

orisha:serve(port: 3101)
| shutdown _ |> _
| failed _ |> _
