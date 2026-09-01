// PGO router case study — hot HttpArena path declared LAST, profile moves it first.
//
// Traffic shape: httparena/workload.py --profile baseline (99%+ /baseline11)
// Run from orisha/:  examples/pgo-router-case/bench.sh

import orisha

// Decoys alphabetically first; HttpArena routes last (codegen order).
orisha:handler = orisha:router(req)
! [GET /admin/alerts] -> { status: 200, body: "decoy-1", content_type: "text/plain" }
! [GET /admin/audit] -> { status: 200, body: "decoy-2", content_type: "text/plain" }
! [GET /admin/config] -> { status: 200, body: "decoy-3", content_type: "text/plain" }
! [GET /admin/health] -> { status: 200, body: "decoy-4", content_type: "text/plain" }
! [GET /admin/metrics] -> { status: 200, body: "decoy-5", content_type: "text/plain" }
! [GET /admin/users] -> { status: 200, body: "decoy-6", content_type: "text/plain" }
! [GET /api/v1/a] -> { status: 200, body: "decoy-7", content_type: "text/plain" }
! [GET /api/v1/b] -> { status: 200, body: "decoy-8", content_type: "text/plain" }
! [GET /api/v1/c] -> { status: 200, body: "decoy-9", content_type: "text/plain" }
! [GET /api/v1/d] -> { status: 200, body: "decoy-10", content_type: "text/plain" }
! [GET /api/v1/e] -> { status: 200, body: "decoy-11", content_type: "text/plain" }
! [GET /api/v1/f] -> { status: 200, body: "decoy-12", content_type: "text/plain" }
! [GET /api/v1/g] -> { status: 200, body: "decoy-13", content_type: "text/plain" }
! [GET /api/v1/h] -> { status: 200, body: "decoy-14", content_type: "text/plain" }
! [GET /api/v1/i] -> { status: 200, body: "decoy-15", content_type: "text/plain" }
! [GET /api/v1/j] -> { status: 200, body: "decoy-16", content_type: "text/plain" }
! [GET /api/v1/k] -> { status: 200, body: "decoy-17", content_type: "text/plain" }
! [GET /api/v1/l] -> { status: 200, body: "decoy-18", content_type: "text/plain" }
! [GET /api/v1/m] -> { status: 200, body: "decoy-19", content_type: "text/plain" }
! [GET /api/v1/n] -> { status: 200, body: "decoy-20", content_type: "text/plain" }
! [GET /api/v1/o] -> { status: 200, body: "decoy-21", content_type: "text/plain" }
! [GET /api/v1/p] -> { status: 200, body: "decoy-22", content_type: "text/plain" }
! [GET /api/v1/q] -> { status: 200, body: "decoy-23", content_type: "text/plain" }
! [GET /api/v1/r] -> { status: 200, body: "decoy-24", content_type: "text/plain" }
! [GET /api/v1/s] -> { status: 200, body: "decoy-25", content_type: "text/plain" }
! [GET /api/v1/t] -> { status: 200, body: "decoy-26", content_type: "text/plain" }
! [GET /api/v1/u] -> { status: 200, body: "decoy-27", content_type: "text/plain" }
! [GET /api/v1/v] -> { status: 200, body: "decoy-28", content_type: "text/plain" }
! [GET /pipeline] -> { status: 200, body: "ok", content_type: "text/plain" }
! [GET /baseline11] -> { status: 200, body: "55", content_type: "text/plain" }
! [GET /json/25] -> { status: 200, body: "{}", content_type: "application/json" }
! [*] -> { status: 404, body: "missing", content_type: "text/plain" }

orisha:serve(port: 9999)
| shutdown _ |> _
| failed _ |> _
