#!/bin/bash
# Orisha Benchmark Suite
# Compares Orisha against nginx, Go, Bun, and Rust actix-web
#
# Usage:
#   ./run.sh              # Run all benchmarks
#   ./run.sh static       # Static file benchmark only
#   ./run.sh dynamic      # Dynamic endpoint benchmark only
#   ./run.sh build        # Build all servers without running benchmarks

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"
DURATION="${DURATION:-10s}"
CONNECTIONS="${CONNECTIONS:-50}"
THREADS="${THREADS:-2}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

mkdir -p "$RESULTS_DIR"

# Port assignments
PORT_ORISHA=3000
PORT_NGINX=3001
PORT_GO=3002
PORT_BUN=3003
PORT_ACTIX=3004
PORT_DOTNET=3005
PORT_MRHTTP=3006

log() { echo -e "${BLUE}==>${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }

check_deps() {
    log "Checking dependencies..."

    command -v wrk >/dev/null 2>&1 || { error "wrk not found. Install: brew install wrk"; exit 1; }
    command -v go >/dev/null 2>&1 || warn "go not found - Go benchmark will be skipped"
    command -v bun >/dev/null 2>&1 || warn "bun not found - Bun benchmark will be skipped"
    command -v cargo >/dev/null 2>&1 || warn "cargo not found - Rust benchmark will be skipped"
    command -v nginx >/dev/null 2>&1 || warn "nginx not found - nginx benchmark will be skipped"
    command -v koruc >/dev/null 2>&1 || warn "koruc not found - Orisha benchmark will be skipped"
    command -v dotnet >/dev/null 2>&1 || warn "dotnet not found - .NET benchmark will be skipped"
    command -v python3 >/dev/null 2>&1 || warn "python3 not found - mrhttp benchmark will be skipped"

    success "Dependency check complete"
}

build_all() {
    log "Building all servers..."

    # Build Go
    if command -v go >/dev/null 2>&1; then
        log "Building Go server..."
        (cd "$SCRIPT_DIR/dynamic/go" && go build -o server main.go)
        success "Go server built"
    fi

    # Build Rust
    if command -v cargo >/dev/null 2>&1; then
        log "Building Rust actix-web server (this may take a while)..."
        (cd "$SCRIPT_DIR/dynamic/rust-actix" && cargo build --release 2>/dev/null)
        success "Rust actix-web server built"
    fi

    # Build Orisha static server
    if command -v koruc >/dev/null 2>&1 && [ -d "$SCRIPT_DIR/../examples/static-server" ]; then
        log "Building Orisha static server..."
        (cd "$SCRIPT_DIR/../examples/static-server" && koruc main.kz 2>/dev/null)
        success "Orisha static server built"
    fi

    # Build Orisha dynamic server
    if command -v koruc >/dev/null 2>&1 && [ -d "$SCRIPT_DIR/dynamic/orisha" ]; then
        log "Building Orisha dynamic server..."
        (cd "$SCRIPT_DIR/dynamic/orisha" && koruc main.kz 2>/dev/null)
        success "Orisha dynamic server built"
    fi

    # Build .NET
    if command -v dotnet >/dev/null 2>&1; then
        log "Building .NET server..."
        (cd "$SCRIPT_DIR/dynamic/dotnet" && dotnet publish -c Release -o bin/publish 2>/dev/null)
        success ".NET server built"
    fi

    # mrhttp doesn't need building (Python)
    # Bun doesn't need building
    success "All servers built"
}

kill_servers() {
    log "Stopping any running servers..."
    pkill -f "nginx.*benchmark" 2>/dev/null || true
    pkill -f "orisha-benchmark" 2>/dev/null || true
    pkill -f "dotnet-benchmark" 2>/dev/null || true
    pkill -f "mrhttp.*server" 2>/dev/null || true
    lsof -ti:$PORT_ORISHA,$PORT_NGINX,$PORT_GO,$PORT_BUN,$PORT_ACTIX,$PORT_DOTNET,$PORT_MRHTTP 2>/dev/null | xargs kill 2>/dev/null || true
    sleep 1
}

benchmark_endpoint() {
    local name="$1"
    local url="$2"
    local output_file="$3"

    echo ""
    log "Benchmarking $name: $url"
    echo "    Duration: $DURATION, Connections: $CONNECTIONS, Threads: $THREADS"

    # Run wrk and capture output
    local result=$(wrk -t$THREADS -c$CONNECTIONS -d$DURATION "$url" 2>&1)
    echo "$result"

    # Extract requests/sec
    local rps=$(echo "$result" | grep "Requests/sec" | awk '{print $2}')
    echo "$name,$url,$rps" >> "$output_file"

    echo "$rps"
}

run_static_benchmark() {
    log "=== STATIC FILE BENCHMARK ==="
    local output_file="$RESULTS_DIR/static_$(date +%Y%m%d_%H%M%S).csv"
    echo "server,url,requests_per_sec" > "$output_file"

    kill_servers

    # Orisha
    if [ -x "$SCRIPT_DIR/../examples/static-server/a.out" ]; then
        log "Starting Orisha server on :$PORT_ORISHA..."
        "$SCRIPT_DIR/../examples/static-server/a.out" &
        sleep 2
        benchmark_endpoint "Orisha" "http://localhost:$PORT_ORISHA/" "$output_file"
        kill_servers
    else
        warn "Orisha server not found"
    fi

    # nginx
    if command -v nginx >/dev/null 2>&1; then
        log "Starting nginx on :$PORT_NGINX..."
        local nginx_conf="$SCRIPT_DIR/static/nginx.conf"
        # Replace BENCHMARK_ROOT with actual path
        sed "s|BENCHMARK_ROOT|$SCRIPT_DIR|g" "$nginx_conf" > /tmp/nginx-benchmark.conf
        nginx -c /tmp/nginx-benchmark.conf &
        sleep 2
        benchmark_endpoint "nginx" "http://localhost:$PORT_NGINX/" "$output_file"
        kill_servers
    else
        warn "nginx not found"
    fi

    # Go
    if [ -x "$SCRIPT_DIR/dynamic/go/server" ]; then
        log "Starting Go server on :$PORT_GO..."
        "$SCRIPT_DIR/dynamic/go/server" &
        sleep 2
        benchmark_endpoint "Go" "http://localhost:$PORT_GO/" "$output_file"
        kill_servers
    else
        warn "Go server not found"
    fi

    # Bun
    if command -v bun >/dev/null 2>&1; then
        log "Starting Bun server on :$PORT_BUN..."
        (cd "$SCRIPT_DIR/dynamic/bun" && bun run server.ts) &
        sleep 2
        benchmark_endpoint "Bun" "http://localhost:$PORT_BUN/" "$output_file"
        kill_servers
    else
        warn "Bun not found"
    fi

    # Rust actix-web
    if [ -x "$SCRIPT_DIR/dynamic/rust-actix/target/release/orisha-benchmark-actix" ]; then
        log "Starting actix-web server on :$PORT_ACTIX..."
        "$SCRIPT_DIR/dynamic/rust-actix/target/release/orisha-benchmark-actix" &
        sleep 2
        benchmark_endpoint "actix-web" "http://localhost:$PORT_ACTIX/" "$output_file"
        kill_servers
    else
        warn "actix-web server not found"
    fi

    # .NET
    if [ -x "$SCRIPT_DIR/dynamic/dotnet/bin/publish/dotnet-benchmark" ]; then
        log "Starting .NET server on :$PORT_DOTNET..."
        (cd "$SCRIPT_DIR/dynamic/dotnet" && ./bin/publish/dotnet-benchmark) &
        sleep 2
        benchmark_endpoint ".NET" "http://localhost:$PORT_DOTNET/" "$output_file"
        kill_servers
    else
        warn ".NET server not found"
    fi

    # mrhttp (Python)
    if command -v python3 >/dev/null 2>&1 && python3 -c "import mrhttp" 2>/dev/null; then
        log "Starting mrhttp server on :$PORT_MRHTTP..."
        (cd "$SCRIPT_DIR/dynamic/mrhttp" && python3 server.py) &
        sleep 2
        benchmark_endpoint "mrhttp" "http://localhost:$PORT_MRHTTP/" "$output_file"
        kill_servers
    else
        warn "mrhttp not found (pip install mrhttp)"
    fi

    echo ""
    success "Static benchmark complete. Results: $output_file"
    cat "$output_file"
}

run_dynamic_benchmark() {
    log "=== DYNAMIC ENDPOINT BENCHMARK ==="
    local output_file="$RESULTS_DIR/dynamic_$(date +%Y%m%d_%H%M%S).csv"
    echo "server,url,requests_per_sec" > "$output_file"

    kill_servers

    # Go
    if [ -x "$SCRIPT_DIR/dynamic/go/server" ]; then
        log "Starting Go server on :$PORT_GO..."
        "$SCRIPT_DIR/dynamic/go/server" &
        sleep 2
        benchmark_endpoint "Go" "http://localhost:$PORT_GO/api/users/42" "$output_file"
        kill_servers
    fi

    # Bun
    if command -v bun >/dev/null 2>&1; then
        log "Starting Bun server on :$PORT_BUN..."
        (cd "$SCRIPT_DIR/dynamic/bun" && bun run server.ts) &
        sleep 2
        benchmark_endpoint "Bun" "http://localhost:$PORT_BUN/api/users/42" "$output_file"
        kill_servers
    fi

    # Rust actix-web
    if [ -x "$SCRIPT_DIR/dynamic/rust-actix/target/release/orisha-benchmark-actix" ]; then
        log "Starting actix-web server on :$PORT_ACTIX..."
        "$SCRIPT_DIR/dynamic/rust-actix/target/release/orisha-benchmark-actix" &
        sleep 2
        benchmark_endpoint "actix-web" "http://localhost:$PORT_ACTIX/api/users/42" "$output_file"
        kill_servers
    fi

    # .NET
    if [ -x "$SCRIPT_DIR/dynamic/dotnet/bin/publish/dotnet-benchmark" ]; then
        log "Starting .NET server on :$PORT_DOTNET..."
        (cd "$SCRIPT_DIR/dynamic/dotnet" && ./bin/publish/dotnet-benchmark) &
        sleep 2
        benchmark_endpoint ".NET" "http://localhost:$PORT_DOTNET/api/users/42" "$output_file"
        kill_servers
    fi

    # mrhttp (Python)
    if command -v python3 >/dev/null 2>&1 && python3 -c "import mrhttp" 2>/dev/null; then
        log "Starting mrhttp server on :$PORT_MRHTTP..."
        (cd "$SCRIPT_DIR/dynamic/mrhttp" && python3 server.py) &
        sleep 2
        benchmark_endpoint "mrhttp" "http://localhost:$PORT_MRHTTP/api/users/42" "$output_file"
        kill_servers
    fi

    # Orisha dynamic
    if [ -x "$SCRIPT_DIR/dynamic/orisha/a.out" ]; then
        log "Starting Orisha dynamic server on :$PORT_ORISHA..."
        "$SCRIPT_DIR/dynamic/orisha/a.out" &
        sleep 2
        benchmark_endpoint "Orisha" "http://localhost:$PORT_ORISHA/api/users/42" "$output_file"
        kill_servers
    else
        warn "Orisha dynamic server not found"
    fi

    echo ""
    success "Dynamic benchmark complete. Results: $output_file"
    cat "$output_file"
}

print_summary() {
    echo ""
    echo "=========================================="
    echo "           BENCHMARK SUMMARY"
    echo "=========================================="
    echo ""
    echo "Results saved in: $RESULTS_DIR/"
    echo ""
    echo "Latest results:"
    ls -la "$RESULTS_DIR/"*.csv 2>/dev/null | tail -5
}

# Main
case "${1:-all}" in
    build)
        check_deps
        build_all
        ;;
    static)
        check_deps
        build_all
        run_static_benchmark
        print_summary
        ;;
    dynamic)
        check_deps
        build_all
        run_dynamic_benchmark
        print_summary
        ;;
    all)
        check_deps
        build_all
        run_static_benchmark
        run_dynamic_benchmark
        print_summary
        ;;
    *)
        echo "Usage: $0 [build|static|dynamic|all]"
        exit 1
        ;;
esac
