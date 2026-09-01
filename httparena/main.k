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

orisha:handler = orisha/httparena:dispatch(req)

// Cleartext for local wrk / baseline+pipeline+json-comp. Board Dockerfile sed-adds TLS for json-tls.
orisha:serve(port: 8080)
| shutdown s |> std/io:print.ln(s)
| failed f |> std/io:print.ln("failed: {{ f:s }}")
