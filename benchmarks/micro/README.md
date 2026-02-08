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
