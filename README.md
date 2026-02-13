# Orisha

A high-performance web framework for the [Koru programming language](https://korulang.org).

Named after the [Orishas](https://en.wikipedia.org/wiki/Orisha) of Yoruba spiritual tradition.

## What it does

Orisha gives you an HTTP server and pattern-matching router, written in Koru and compiled to native code via Zig. Routes are declared with a concise DSL and compiled down to straight-line if/return chains -- no runtime dispatch overhead.

```koru
~import "$orisha"

~orisha:handler = orisha:router(req)
| [GET /]           _ |> response { status: 200, body: "Hello World",  content_type: "text/plain" }
| [GET /users/:id]  p |> response { status: 200, body: p.id,          content_type: "text/plain" }
| [*]               _ |> response { status: 404, body: "Not Found",   content_type: "text/plain" }

~orisha:serve(port: 3000)
| shutdown s |> io.println(message: s.reason)
| failed   f |> io.println(message: f.msg)
```

## Getting started

Requires the [Koru compiler](https://korulang.org) (`koruc`).

```bash
koruc examples/router-test/main.kz && ./examples/router-test/main
```

## Project layout

```
lib/
  index.kz       # Server core (kqueue worker pool, request parsing)
  routing.kz      # Pattern-matching router
examples/
  router-test/    # Multi-route example with dynamic params
  hello/          # Minimal hello-world server
  static-server/  # Static file serving
benchmarks/       # wrk scripts and result CSVs
```

## License

MIT
