# Orisha Benchmark Suite

Compares Orisha against nginx, Go, Bun, Rust actix-web, .NET, and mrhttp for both static and dynamic endpoints.

## Quick Start

```bash
# Run all benchmarks
./run.sh

# Run only static file benchmark
./run.sh static

# Run only dynamic endpoint benchmark
./run.sh dynamic

# Build all servers without benchmarking
./run.sh build
```

## Requirements

- `wrk` - HTTP benchmarking tool (`brew install wrk`)
- `go` - Go compiler (for Go benchmark)
- `bun` - Bun runtime (for Bun benchmark)
- `cargo` - Rust compiler (for actix-web benchmark)
- `nginx` - nginx server (for nginx benchmark)
- `koruc` - Koru compiler (for Orisha benchmark)
- `dotnet` - .NET 8 SDK (for .NET benchmark)
- `python3` + `mrhttp` - Python with mrhttp (`pip install mrhttp`)

## Endpoints Tested

All servers implement the same API:

| Endpoint | Type | Response |
|----------|------|----------|
| `GET /` | Static | HTML page (embedded at compile time) |
| `GET /about` | Static | HTML page |
| `GET /api/health` | Dynamic | `{"status":"ok"}` |
| `GET /api/users/:id` | Dynamic | `{"id":"<id>","name":"User <id>"}` |

## Port Assignments

| Server | Port |
|--------|------|
| Orisha | 3000 |
| nginx | 3001 |
| Go | 3002 |
| Bun | 3003 |
| actix-web | 3004 |
| .NET | 3005 |
| mrhttp | 3006 |

## Configuration

Environment variables:

```bash
DURATION=10s      # Benchmark duration (default: 10s)
CONNECTIONS=50    # Concurrent connections (default: 50)
THREADS=2         # wrk threads (default: 2)
```

Example:
```bash
DURATION=30s CONNECTIONS=100 ./run.sh static
```

## Results

Results are saved to `results/` as CSV files with timestamps.

## Architecture Comparison

| Server | Static Files | Route Matching | JSON Serialization |
|--------|--------------|----------------|-------------------|
| **Orisha** | Compile-time blob | Switch on path | Manual sprintf |
| **nginx** | sendfile() + cache | Config-based | Built-in |
| **Go** | embed.FS | Prefix tree | encoding/json |
| **Bun** | File read at startup | Regex match | Response.json() |
| **actix-web** | include_str!() | Macro-generated tree | serde_json |
| **.NET** | ReadAllText at startup | Minimal API tree | Manual string |
| **mrhttp** | Read at startup | uvloop + httptools | Manual f-string |

## Why Orisha Should Win (Static)

1. **Zero disk I/O** - Response is a compile-time constant in the binary
2. **Pre-computed headers** - ETag, Content-Length, Content-Type all baked in
3. **Single write() syscall** - Headers + body concatenated at compile time

## Why Orisha Can Compete (Dynamic)

1. **Compile-time route optimization** - Can reorder routes based on access logs
2. **No framework overhead** - Direct Zig code generation
3. **Pattern branches** - `| [GET /users/:id] |>` compiles to efficient switch

## Stretch Goal: Log-Based Route Optimization

Only Orisha can do this:

```bash
# Feed access logs to compiler
koruc main.kz --optimize-routes=access.log

# Compiler reorders route table by frequency
# Hot routes become first comparisons
```

This is architecturally impossible for runtime frameworks that don't know routes at compile time.
