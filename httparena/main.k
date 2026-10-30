// Orisha on HttpArena — like genhttp-kestrel: import the framework, wire routes, listen.
//
//   cd orisha/httparena
//   mkdir -p certs && cp fixtures/* certs/
//   DATASET_PATH=./data/dataset.json koruc main.k && ./a.out

import orisha
import httparena/handlers
import std/io
import std/build
import std/compress

orisha:handler = orisha:router(req)
! [GET /pipeline] -> { status: 200, body: "ok", content_type: "text/plain", body_static: true }
! [GET /baseline11] |> httparena/handlers:baseline(req)
! [GET /baseline2] |> httparena/handlers:baseline(req)
! [POST /baseline11] |> httparena/handlers:baseline(req)
! [GET /json/:count] p |> httparena/handlers:json(req, p.count)
! [GET /ws] |> httparena/handlers:ws-upgrade(req)
! [POST /echo] |> httparena/handlers:echo(req)
! [POST /benchmark.BenchmarkService/GetSum] |> httparena/handlers:grpc-sum(req)
! [GET /delay/:ms] p |> httparena/handlers:delay(req, p.ms)
! [GET /static/:file] p |> httparena/handlers:static-file(req, p.file)
! [GET /async-db] |> httparena/handlers:async-db(req)
! [*] -> { status: 404, body: "not found", content_type: "text/plain" }

// echo-ws: every complete message the pump reassembles goes straight back,
// opcode preserved. Control frames never reach this arm.
orisha/pump:ws-frame = orisha/pump:ws-send(x: f, payload: f.raw, f.opcode)

// Cleartext for local wrk / baseline+pipeline+json-comp. Board Dockerfile sed-adds TLS for json-tls.
// std/compress warmup: pulls the module into the program and bakes the
// first dynamic tree before the first request pays for it.
std/compress:gzip(data: "warmup")
| compressed c |> std/io:print.ln("compress ready")
| error e |> std/io:print.ln("compress failed")

orisha:serve(port: 8080)
| shutdown s |> std/io:print.ln(s)
| failed f |> std/io:print.ln("failed: {{ f:s }}")
