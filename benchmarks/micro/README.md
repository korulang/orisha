# Microbenchmarks

This folder contains small, focused microbenchmarks used to validate hotspot assumptions.

## Request line parsing

Bench: `parse_request.zig`

Run:
```sh
zig run benchmarks/micro/parse_request.zig -O ReleaseFast -- 10000000
```

Notes:
- This measures parsing only (method/path extraction from a request line).
- It does not include allocation, socket I/O, or response generation.

## Router dispatch (compiled, inline)

Bench: `router_dispatch.zig`

Run (ensure generated code exists first):
```sh
koruc benchmarks/dynamic/orisha/main.kz
zig run benchmarks/micro/router_dispatch.zig -O ReleaseFast -- 10000000
```

Notes:
- Uses the generated `output_emitted.zig` from the dynamic Orisha benchmark.
- Calls the compiled handler in a tight loop, so the dispatch is exactly what the compiler emits.
- This is the honest, compile-time-folded router path.

## Response build (no socket I/O)

Bench: `response_build.zig`

Run:
```sh
zig run benchmarks/micro/response_build.zig -O ReleaseFast -- 1000000
```

Notes:
- Measures response string building (status line + headers + body).
- Does **not** include syscalls or network write.
