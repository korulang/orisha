// Orisha on HttpArena — like genhttp-kestrel: import the framework, wire routes, listen.
//
//   cd orisha/httparena
//   mkdir -p certs && cp fixtures/* certs/
//   DATASET_PATH=./data/dataset.json koruc main.k && ./a.out

import orisha
import std/io
import std/build
import std/compress

orisha:handler = orisha:router(req)
! [GET /pipeline] -> { status: 200, body: "ok", content_type: "text/plain", body_static: true }
! [GET /baseline11] |> orisha/httparena:baseline(req)
! [POST /baseline11] |> orisha/httparena:baseline(req)
! [GET /json/:count] p |> orisha/httparena:json(req, p.count)
! [*] -> { status: 404, body: "not found", content_type: "text/plain" }

// Cleartext for local wrk / baseline+pipeline+json-comp. Board Dockerfile sed-adds TLS for json-tls.
// std/compress warmup: pulls the module into the program and bakes the
// first dynamic tree before the first request pays for it.
std/compress:gzip(data: "warmup")
| compressed c |> std/io:print.ln("compress ready")
| error e |> std/io:print.ln("compress failed")

orisha:serve(port: 8080)
| shutdown s |> std/io:print.ln(s)
| failed f |> std/io:print.ln("failed: {{ f:s }}")
