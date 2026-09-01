// Orisha on HttpArena — like genhttp-kestrel: import the framework, wire routes, listen.
//
//   cd orisha/httparena
//   mkdir -p certs && cp fixtures/* certs/
//   DATASET_PATH=./data/dataset.json koruc main.k && ./a.out

import orisha
import std/io
import std/build

std/build:requires {
    exe.linkSystemLibrary("z");
}

orisha:handler = orisha:router(req)
! [GET /pipeline] |> orisha/httparena:pipeline(req)
! [GET /baseline11] |> orisha/httparena:baseline(req)
! [POST /baseline11] |> orisha/httparena:baseline(req)
! [GET /json/:count] p |> orisha/httparena:json(req, p.count)
! [*] -> { status: 404, body: "not found", content_type: "text/plain" }

// Cleartext for local wrk / baseline+pipeline+json-comp. Board Dockerfile sed-adds TLS for json-tls.
orisha:serve(port: 8080)
| shutdown s |> std/io:print.ln(s)
| failed f |> std/io:print.ln("failed: {{ f:s }}")
