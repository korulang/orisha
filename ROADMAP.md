# Orisha HTTP Framework - Development Roadmap

**Vision**: Zero-boilerplate HTTP framework using Koru's compile-time metaprogramming to generate routing, middleware, and server infrastructure.

---

## ✅ Phase 0: Foundation (COMPLETED)

### Core Compiler Features
- [x] Module resolution with `koru.json` path aliases
- [x] Directory imports with submodules
- [x] Zero memory leaks in import system
- [x] Fixed path resolution bugs

### Basic Orisha Structure
- [x] Created Orisha repository structure
- [x] Basic Eshu module (HTTP routing)
- [x] Hello World example compiles successfully
- [x] `~[comptime|norun]` event declarations work

---

## 🎯 Phase 1: Metaprogramming Foundation

### Compile-Time Route Collection
The killer feature: Routes declared with `~orisha.eshu:route()` should be automatically collected at compile time and used to generate a routing table.

**What We Need:**
1. **AST Walking for Comptime Events**
   - Compiler must collect all `~orisha.eshu:route()` invocations during AST analysis
   - Extract: method, path, and the continuation block (the handler)
   - Store in a compile-time registry

2. **Handler as Flow Continuation**
   ```koru
   ~orisha.eshu:route(method: "GET", path: "/hello")
     | http_context ctx |>
       orisha.eshu:send_text(ctx, "Hello!")
   ```
   - Standard Koru flow syntax - `route` emits `http_context` branch
   - The continuation block `| http_context ctx |> ...` is the handler
   - Compiler walks AST, finds these flows, stores the continuation for code generation
   - No special metaprogramming syntax needed - just regular flows!

3. **Code Generation from Collected Routes**
   - After collecting all routes, generate a routing table
   - Generate dispatch logic: match HTTP method + path → call handler
   - Compile handlers into callable functions

**Compiler Features to Build:**
- [ ] AST walker for `~[comptime|norun]` events
- [ ] Route registry data structure
- [ ] Source block serialization/deserialization
- [ ] Code generation pass for routing tables
- [ ] Integration with backend emitter

### Example Flow:
```koru
// User writes this:
~orisha.eshu:route(method: "GET", path: "/hello")
  | http_context ctx |>
    orisha.eshu:send_text(ctx, "Hello!")

~orisha.eshu:route(method: "POST", path: "/api/data")
  | http_context ctx |>
    // ... handle POST
```

**Compiler generates this (conceptually):**
```zig
const RouteTable = struct {
    fn dispatch(method: []const u8, path: []const u8, ctx: HttpContext) !void {
        if (std.mem.eql(u8, method, "GET") and std.mem.eql(u8, path, "/hello")) {
            return handle_route_0(ctx);
        }
        if (std.mem.eql(u8, method, "POST") and std.mem.eql(u8, path, "/api/data")) {
            return handle_route_1(ctx);
        }
        return error.NotFound;
    }

    fn handle_route_0(ctx: HttpContext) !void {
        // Generated from first route's Source block
        orisha.eshu.send_text(ctx, "Hello!");
    }

    fn handle_route_1(ctx: HttpContext) !void {
        // Generated from second route's Source block
        // ...
    }
};
```

---

## 🚀 Phase 2: HTTP Routing (Eshu)

### Basic Features
- [ ] Static path matching: `/hello`, `/api/users`
- [ ] Method routing: GET, POST, PUT, DELETE, PATCH
- [ ] Path parameters: `/users/:id`, `/posts/:slug`
- [ ] Query parameter parsing
- [ ] Request/response types

### Advanced Routing
- [ ] Wildcard matching: `/files/*`
- [ ] Regex paths: `/posts/[0-9]+`
- [ ] Route groups/prefixes
- [ ] Route priorities/ordering

### HTTP Context
- [ ] Request data: method, path, headers, body
- [ ] Response builders: text, JSON, HTML, status codes
- [ ] Cookie handling
- [ ] Header management

---

## 🔥 Phase 3: Middleware (Ogun - The Blacksmith)

**Vision**: Middleware as event taps that intercept HTTP flows.

### Core Middleware
- [ ] Authentication/Authorization
- [ ] Logging
- [ ] CORS
- [ ] Rate limiting
- [ ] Compression

### Middleware as Taps
```koru
// Middleware intercepts route flows
~tap orisha.ogun:auth_required
  from orisha.eshu:route on http_context
  when ctx.path.startsWith("/api")
  |> check_auth(ctx)
    | authorized |> continue
    | unauthorized |> send_401(ctx)
```

---

## 💾 Phase 4: State Management (Oshun - River of Data)

### Session Management
- [ ] Session storage (memory, Redis)
- [ ] Cookie-based sessions
- [ ] JWT tokens

### Database Integration
- [ ] Connection pooling
- [ ] Query builders
- [ ] Migrations (compile-time!)

---

## ⚡ Phase 5: Real-Time (Oya - Wind & Change)

### WebSocket Support
- [ ] WebSocket handshake
- [ ] Message routing
- [ ] Broadcast/multicast

### Server-Sent Events
- [ ] SSE connections
- [ ] Event streaming

---

## 🎨 Phase 6: Content Handling (Yemoja - Mother of Waters)

### Request Parsing
- [ ] JSON body parsing
- [ ] Form data (urlencoded)
- [ ] Multipart/form-data (file uploads)
- [ ] XML parsing

### Response Rendering
- [ ] Template engine integration
- [ ] JSON serialization
- [ ] Content negotiation

---

## ⚔️ Phase 7: Performance (Shango - Thunder & Lightning)

### Optimization
- [ ] Route trie for fast matching
- [ ] Zero-copy parsing where possible
- [ ] Connection pooling
- [ ] Static file serving (sendfile)

### Benchmarking
- [ ] Compare with Go HTTP, Rust Axum, Node Express
- [ ] Latency metrics
- [ ] Throughput testing

---

## 🛠️ Development Strategy

### Test-Driven Development
Each feature should have:
1. **Regression test** in Koru compiler test suite
2. **Integration test** in Orisha examples
3. **Performance benchmark** where applicable

### Incremental Approach
1. Get ONE route working end-to-end first
2. Add more routes, test dispatch
3. Add path parameters
4. Add middleware
5. Keep building...

### Documentation
- [ ] API reference
- [ ] Tutorial: Build a blog in 30 minutes
- [ ] Example: REST API with auth
- [ ] Example: WebSocket chat
- [ ] Example: File upload service

---

## 🎯 Immediate Next Steps

1. **Implement Route Collection**
   - Modify compiler to walk AST for `~[comptime|norun]` events
   - Build route registry data structure
   - Print collected routes to verify it works

2. **Implement http_context**
   - Define actual fields: method, path, headers, body
   - Add request parsing helpers
   - Add response building methods

3. **Generate Routing Table**
   - From collected routes, generate dispatch function
   - Handle method + path matching
   - Route to correct handler

4. **Test with Real HTTP**
   - Integrate with Zig's std.http.Server
   - Accept real HTTP requests
   - Call generated dispatch function
   - Send real HTTP responses

5. **Iterate**
   - Build examples
   - Find rough edges in compiler
   - Fix bugs (like we just did with imports!)
   - Keep tightening the core toolchain

---

## 🌊 The Orisha Philosophy

**"The framework emerges from the code itself."**

Users write what they want:
```koru
~orisha.eshu:route(method: "GET", path: "/hello")
  | http_context ctx |>
    orisha.eshu:send_text(ctx, "Hello!")
```

The compiler understands their intent and generates optimal infrastructure. No routers to configure, no middleware chains to wire up, no boilerplate. Just pure intention expressed in code.

This is what makes Koru special. This is why we're building it.

**Let's make HTTP routing beautiful.** 🚀
