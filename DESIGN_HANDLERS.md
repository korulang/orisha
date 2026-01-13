# Orisha Handler Design (Aspirational)

## Current State

Orisha currently has:
- `~route(GET /path) { ... }` - static routes with Source block config
- Compile-time route collection
- Pre-compressed responses embedded in binary

The server runtime is mostly Zig with thin Koru wrapping.

## Proposed Design

Split routes into two distinct event types:

### Static Routes

```koru
~route.static(GET /) {
  "directory": "public",
  "compression": "gzip"
}

~route.static(GET /assets) {
  "directory": "static",
  "cache": "immutable"
}
```

Declarative, Source block config. Collected and embedded at compile time.

### Dynamic Handlers

```koru
~route.handler(GET /api/health)
| request _ |> ok "healthy"

~route.handler(GET /admin)
| request r |>
    if(r.role != "admin")
    | then |> not_found "Nothing here"
    | else |> ok "Secret admin data"

~route.handler(GET /old-page)
| request _ |> redirect { url: "/new-page" }
```

Flow-based handlers validated against a response event shape.

## Response Event Shape

```koru
~event response_handler { req: *Request[allocated!] }
| ok []const u8              // 200 OK with body
| not_found []const u8       // 404 Not Found
| redirect { url: []const u8 }  // 302 redirect (or configurable code)
| json { ... }               // JSON response (shape TBD)
| error { code: u16, msg: []const u8 }  // Error responses
```

Branch names ARE semantics. No magic status codes.

### Identity Branch Constructors

```koru
| request _ |> ok "Hello!"
```

The `ok "Hello!"` is an identity branch constructor - shorthand for `ok { body: "Hello!" }` when the branch has a single field or takes a direct value.

## Open Questions

### 1. JSON Response Shape

How do we handle arbitrary JSON data? Options:

**Option A: anyopaque**
```koru
| json { status: ?u16, data: anyopaque }
```
Runtime serializes `data` to JSON.

**Option B: Source block**
```koru
| request r |> json {
    "user": "${r.user}",
    "timestamp": ${now()}
}
```
Template interpolation in Source (not currently supported).

**Option C: Pre-serialized**
```koru
| json { body: []const u8 }
```
User serializes, framework just sets content-type.

### 2. Request Lifecycle

The `*Request[allocated!]` obligation - does the framework auto-dispose, or does each response branch discharge it explicitly?

Likely: Framework handles deallocation. User never sees it.

### 3. Streaming / WebSocket

Different event types entirely?
```koru
~route.stream(GET /api/events)
| connection c[close!] |> ...

~route.websocket(GET /ws)
| connection c |> ...
```

### 4. Middleware / Composition

How do we compose handlers? Auth checks, logging, etc.

```koru
~route.handler(GET /api/users)
| request r |>
    auth:require(r)
    | authorized user |>
        db:query(...)
        | rows |> ok { json: rows }
    | unauthorized |> error { code: 401, msg: "Nope" }
```

Or as decorator-style annotations?

## Integration with @korulang/gzip

Static routes: Framework compresses at compile time (current behavior).

Dynamic handlers: Framework could compress responses transparently based on Accept-Encoding header. Handler just returns `ok "data"`, never thinks about encoding.

## Implementation Steps

1. Verify identity branch constructors work in parser
2. Define `route.static` and `route.handler` events
3. Define `response_handler` shape
4. Update route collector to handle both types
5. Wire dynamic handlers into runtime
6. Add transparent gzip for dynamic responses
