// Orisha Static Server for korulang.org
//
// Serves the SvelteKit static build of korulang.org with SPA fallback.
// All files are embedded INTO THE BINARY at compile time.
//
// Build:
//   cd ~/src/korulang_org && pnpm build:static
//   cd ~/src/orisha/examples/korulang-site && koruc main.kz && ./a.out
//
// Cross-compile for Linux:
//   koruc main.kz --build=linux        (epoll)
//   koruc main.kz --build=io-uring     (io_uring, needs Linux 5.1)

import orisha
import std/io
import std/build
import std/package

std/package:requires.npm { "@korulang/gzip": "^0.0.1" }

// A build flag picks the LOOP; it does not pick the machine. Without these the
// Linux builds compiled for the host and produced a Mach-O binary — the header
// above said "cross-compile" and the command did nothing of the sort.
//
// musl, statically linked, so the result runs on a bare kernel with no libc to
// find — which is what makes a `FROM scratch` container possible.
[build(linux)]std/build:config {
    "target": "x86_64-linux-musl"
}

[build(io-uring)]std/build:config {
    "target": "x86_64-linux-musl"
}

orisha:static(name: "site", root: "../../../korulang_org/build", fallback: "200.html")

orisha:handler = orisha:static-router(name: "site")

orisha:serve(port: 3000)
| shutdown s |> std/io:print.ln(s)
| failed f |> std/io:print.ln(f)
