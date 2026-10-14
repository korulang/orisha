// Orisha — the contract.
//
// Everything Orisha declares lives here, and nothing in this file is Zig, so
// there is no parser to switch out of and not a single `~` anywhere. The Zig
// that implements it — the socket calls, the request parser, the router
// transform — sits in the companion `index.kz` beside this file. Same stem,
// same module: the compiler merges them.
//
// That split is the whole reason this file reads the way it does. These
// declarations used to live inside 1,056 lines of Zig, which forced a `~` onto
// every one of them; the character was never about the Koru, it was about the
// host language it was sharing a file with.
//
// Public API:
//   orisha:serve(port)              - Start server (calls abstract handler for each request)
//   orisha:handler                  - Abstract event users implement for request handling
//   orisha:router(req)              - Pattern-branch router transform
//   orisha:static(name, root, ...)  - Declare static files to embed at compile time
//   orisha:static-router(name)      - Transform: inline static file lookup + fallback
//   orisha:header(req, name)        - One request header, scanned lazily -> ?string
//   orisha:cookie(req, name)        - One pair out of the Cookie header -> ?string
//   orisha:form(req, name)          - One urlencoded field out of req.body -> ?string
//   orisha:query-param(req, name)   - The same codec over req.query -> ?string
//   Response.extra_headers          - CRLF block of response headers (Location,
//                                     Set-Cookie, ...) spliced into the head
//
// Example (simplest server):
//   ~orisha:handler -> { status: 200, body: "Hello!", content_type: "text/plain" }
//   ~orisha:serve(port: 3001)
//
// Example (API + static):
//   ~orisha:handler = orisha:router(req)
//   ! [GET /api/health] -> { status: 200, body: "ok", content_type: "application/json" }
//   ! [*] |> orisha:static-router(name: "site")
//
// Example (pure static site):
//   ~import orisha
//   ~orisha:static(name: "site", root: "build", fallback: "200.html")
//   ~orisha:handler = orisha:static-router(name: "site")
//   ~orisha:serve(port: 3000)

import std/compiler
import std/io
import std/build
import orisha/pump

// ============================================================================
// LISTEN - Start listening on a port
// ============================================================================
// `*ServerHandle`, `*ConnHandle` and `*Request` are Zig types declared in the
// companion. A contract may NAME a host type it does not itself declare —
// what it may not do is contain host code.

pub tor listen { port: u16 }
| listening *ServerHandle
| failed string

// ============================================================================
// ACCEPT - Accept a connection and read the request
// ============================================================================

pub tor accept { server: *ServerHandle }
| request { req: *Request, conn: *ConnHandle, server: *ServerHandle }
| failed { msg: string, server: *ServerHandle }

// ============================================================================
// SEND - Send HTTP response and close connection
// ============================================================================

pub tor send { conn: *ConnHandle, status: u16, body: string, content_type: ?string }
| sent
| failed string

// ============================================================================
// HANDLER - Abstract event for request handling
// ============================================================================
// Users implement this to handle requests. Default returns 404.
//
// @retain: handler_event is referenced from the serve proc's raw Zig via
// $mod.handler_event.handler(...) — invisible to the dead-stripper.

[abstract|retain]pub tor handler { req: *Request } -> Response

// Default implementation - 404 for everything
handler -> { status: 404, body: "Not Found", content_type: null }

// PRE-REQUEST DISPATCH — routes whose answer never needed the Request.
// `! [GET /x] -> { ... }` literal arms produce a fixed Response by
// construction: no `req` exists in their scope, so they are provably
// request-free. The router transform collects those arms into this impl —
// answer() consults it BEFORE materializing Request/head fields, and a hit
// skips all of that machinery. Miss (null) falls through to the full
// handler unchanged. Default: nothing is request-free.
//
// @retain: handler_lite_event is referenced from answer's raw Zig via
// $mod.handler_lite_event.handler(...) — invisible to the dead-stripper.

[abstract|retain]pub tor handler-lite { method: string, path: string } -> ?Response

// Default implementation - no request-free routes
handler-lite -> null

// ============================================================================
// INIT — app-level setup, once, before any worker exists
// ============================================================================
// A server that loads a dataset, seeds a store, or warms a codec does it
// here: `serve` fires init exactly once on the calling thread BEFORE the
// pump stands up a listener or a worker, so whatever init writes is visible
// to every worker by thread-spawn ordering — no lock needed on custody that
// is never written again. `| failed` refuses startup: an app that cannot
// stand up its custody does not get to answer requests over a half-load.
// The default is a no-op — most apps own no process-lifetime state.
//
//   orisha:init = seed()
//   | ok |> _ => ready
//   | failed e => failed e
//
[abstract]pub tor init {}
| ready
| failed string

// Default implementation - nothing to set up
init => ready

// ============================================================================
// SERVE — a Koru flow over a platform pump
// ============================================================================
// `serve` used to be two ~200-line Zig bodies, one per readiness mechanism,
// that differed in about twenty lines and duplicated everything else. The loop
// now lives in orisha/pump, one variant per platform; what remains here is the
// part that is the same everywhere, and it is a flow.
//
// Adding a platform is a `~proc run|<name>` in orisha/pump plus a line in the
// variants block. Nothing in this file changes.

pub tor serve { port: u16, tls_port: ?u16, cert_path: ?string, key_path: ?string }
| shutdown string
| failed string

serve =
    orisha:init()
    | failed e -> failed e
    | ready |> orisha/pump:run(port, tls_port, cert_path, key_path)
        ! arrived x |> orisha:answer(x): a |> orisha/pump:reply(x, a.head, a.body, a.date_hole, a.head_static, a.body_static, hang: a.close)
            | sent |> orisha:release-body(a.body, allocated: a.body_allocated)
            | broken _ |> orisha:release-body(a.body, allocated: a.body_allocated)
        ! frame f |> orisha/pump:ws-frame(f)
        ! closed fd |> orisha/pump:ws-closed(fd)
        | stopped s -> shutdown s
        | failed e -> failed e

// ============================================================================
// ANSWER — parse one request, run the handler, shape the response
// ============================================================================
// Platform-free by construction: it takes the exchange the pump dispatched
// and returns response bytes — never a platform handle type. Every pump
// shares it. The body is in the companion.
//
// It reads `x.raw` in place rather than `pump:raw`'s arena copy, and the
// parse `scanRequest` already produced rather than re-scanning the head —
// one request, one walk.
pub tor answer { x: *orisha/pump:Exchange } -> { head: string, body: string, body_allocated: bool, date_hole: usize, close: bool, head_static: bool, body_static: bool }

// Free a handler body that fmt.blk allocated. Static slices and fmt:ln TLS
// buffers arrive with allocated=false; those must not be freed.
pub tor release-body { body: string, allocated: bool }

// ============================================================================
// REQUEST HEADERS — lazy reads over the raw block
// ============================================================================
// `req.headers` is the whole header block — request line through the blank
// line — borrowed from the request bytes. These accessors scan it only when
// asked, so a route that never asks pays one stored slice and nothing more.
// Names are case-insensitive (RFC 9110); the answer borrows the request and
// dies with it. `Cookie`, `Origin`, `Sec-WebSocket-*` — everything the client
// sent is reachable this way.
//
//   orisha:header(req: req, name: "origin")
//   orisha:header(req: req, name: "sec-websocket-key")

pub tor header { req: *Request, name: string } -> ?string

// One pair out of the `Cookie` header — "a=1; b=2" — so a handler does not
// split the header itself. Cookie names are case-sensitive (RFC 6265).
pub tor cookie { req: *Request, name: string } -> ?string

// ============================================================================
// BODY FIELDS — one codec, two seams
// ============================================================================
// `form` reads application/x-www-form-urlencoded fields out of `req.body` and
// refuses (null) a request that never declared that content type — parsing a
// JSON body as pairs is how a string value becomes a phantom field.
// `query-param` runs the same codec over `req.query`, where no declaration
// exists. `+` is a space, %XX a byte; a pair without `=` is a flag and
// matches no name.

pub tor form { req: *Request, name: string } -> ?string
pub tor query-param { req: *Request, name: string } -> ?string

// The raw spans the parsed request carried — `body` is the entity bytes
// exactly as received (no codec, no content-type gate) and `query` is the
// unparsed query string. Handlers that need more than one field — or none
// of the named-param codec — read the span and parse it themselves. Both
// borrow the request and die with it.
pub tor body { req: *Request } -> ?string
pub tor query { req: *Request } -> ?string

// The descriptor the request arrived on — `pump:fileno`'s handler-side
// twin. A route that upgrades can register the connection for `ws-send-fd`
// pushes, and `! closed` reports the same integer when it goes away.
pub tor fd { req: *Request } -> usize

// ============================================================================
// WS-ACCEPT — the RFC 6455 handshake value
// ============================================================================
// base64(SHA-1(`Sec-WebSocket-Key` + the fixed GUID)) — the one part of an
// upgrade a handler cannot spell itself. Null when the request carries no
// key. The answer is a `status: 101` Response whose `extra_headers` spell
// `Upgrade`/`Connection: Upgrade`/`Sec-WebSocket-Accept`; `answer` emits the
// 101 head and the pump flips the connection to frames on the way out.

pub tor ws-accept { req: *Request } -> ?string

// ============================================================================
// PLATFORM SELECTION
// ============================================================================
// One line per platform. The pump is what changes; serve never does.

[build(linux)]std/build:variants {
    "orisha/pump:drive": "epoll"
}
| configured _ |> _
| skipped _ |> _
| invalid-event _ |> _

// Linux again, with the newer mechanism. epoll answers "which of these is
// ready"; io_uring is told the read ALREADY HAPPENED, so the loop handles a
// result rather than a hint. Needs Linux 5.1, which is why it is a separate
// choice rather than the Linux default.
[build(io-uring)]std/build:variants {
    "orisha/pump:drive": "io-uring"
}
| configured _ |> _
| skipped _ |> _
| invalid-event _ |> _

// A unikernel selects BOTH: the loop, and the writer. `reply`'s default body
// goes through `posix.write`, which has no implementation on a freestanding
// target, and it is reached from the `arrived` arm on every request — so it is
// not one of the bodies the target can simply leave unanalyzed.
//
// `fill` is deliberately NOT here, and the reason is worth stating: this block
// rewrites the call sites the FLOW makes. The pump reads from inside its own
// loop, in raw Zig, and a line here would have no effect on that call — it would
// read as selection while selecting nothing. The unikernel loop names the reader
// it wants directly instead. See `drive|unikraft` in the companion.
[build(unikraft)]std/build:variants {
    "orisha/pump:drive": "unikraft",
    "orisha/pump:reply": "unikraft",
    "orisha/pump:ws-send": "unikraft",
    "orisha/pump:ws-close": "unikraft"
}
| configured _ |> _
| skipped _ |> _
| invalid-event _ |> _

// ============================================================================
// ROUTER - Pattern-branch router transform
// ============================================================================
// Transforms pattern branches into dispatch logic.
//
// Usage:
//   ~orisha:handler = orisha:router(req)
//   ! [GET /] _ -> { status: 200, body: "Hello", content_type: "text/plain" }
//   ! [GET /users/:id] p -> { status: 200, body: p.id, content_type: "text/plain" }
//   ! [*] _ -> { status: 404, body: "Not Found", content_type: "text/plain" }

[comptime|transform]pub tor router {
    invocation: *const Invocation,
    item: *const Item,
    program: *const Program,
    allocator: std.mem.Allocator
} -> SiteResult

// ============================================================================
// STATIC - Declare files to embed at compile time
// ============================================================================
// Data-only event.
// - name: identifier for referencing via static-router
// - root: directory to embed (relative to the consuming file)
// - fallback: optional file for SPA fallback (relative to root, e.g. "200.html")

[comptime]pub tor static { name: string, root: string, fallback: ?string }

// ============================================================================
// STATIC ROUTER - Compile-time transform for static file dispatch
// ============================================================================
// Generates inline lookup code that:
//   1. Imports generated/<name>_routes.zig
//   2. Calls lookupWithEtag(method, path, if_none_match, accept_encoding)
//   3. Returns pre-built response (or fallback, or 404)
//
// Works as top-level handler or nested in a router catch-all:
//   ~orisha:handler = orisha:static-router(name: "site")
//   ! [*] |> orisha:static-router(name: "site")

[comptime|transform]pub tor static-router {
    invocation: *const Invocation,
    item: *const Item,
    program: *const Program,
    allocator: std.mem.Allocator
} -> SiteResult
