// Orisha on TechEmpower — import the framework, wire the TFB routes, listen.
//
//   cd orisha/techempower
//   koruc main.k --release=fast && ./a.out

import orisha
import techempower/handlers
import std/io
import std/build

orisha:handler = orisha:router(req)
! [GET /plaintext] |> techempower/handlers:plaintext(req)
! [GET /json] |> techempower/handlers:json(req)
! [GET /db] |> techempower/handlers:db(req)
! [GET /queries] |> techempower/handlers:queries(req)
! [GET /fortunes] |> techempower/handlers:fortunes(req)
! [GET /updates] |> techempower/handlers:updates(req)
! [GET /cached-worlds] |> techempower/handlers:cached-worlds(req)
! [*] -> { status: 404, body: "not found", content_type: "text/plain" }

orisha:serve(port: 8080)
| shutdown s |> std/io:print.ln(s)
| failed f |> std/io:print.ln("failed: {{ f:s }}")
