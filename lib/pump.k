// Orisha's pump — the contract.
//
// What a pump is: the thing that owns the readiness loop and hands the flow one
// exchange at a time. Every declaration is here; the loop bodies, one per
// platform, are in the companion `pump.kz`. This file has no host language in
// it, so it has no `~` in it either.

// TLS helpers live in koru/openssl; imported from orisha/index.k so emission
// orders koru_openssl before this submodule in the merged module.

// ============================================================================
// RUN — context-aware surface; DRIVE — the standalone loop it lowers to
// ============================================================================
// `run` is a transform in the companion `pump.kz`: with no `std/pump` open
// above the call site it emits `drive` — the accept loop, one variant per
// platform — and inside an open pump it emits `init` plus the join units that
// capture it. Either way `! arrived` fires once per request and RESUMES, and
// `! frame` fires once per complete websocket message after a 101 answer
// flips the connection; `| stopped` and `| failed` are the two ways it ends. `*Exchange` is a host
// type the companion declares — a contract may name one, it just may not
// define one.

pub tor drive { port: u16, tls_port: ?u16, cert_path: ?string, key_path: ?string }
! arrived *Exchange
! frame *Exchange
! closed usize
| stopped string
| failed string

// The transform signature rides machine-interface types — ABI names spelled
// bare, `Allocator` qualified through std/compiler (refine.k convention).

[comptime|transform|claims_descendants]pub tor run {
    item: *const Item,
    program: *const Program,
    allocator: std/compiler:Allocator
} -> SiteResult

// ============================================================================
// RETIRE — the verdict a captured run's retire unit asks for
// ============================================================================
// A compound pump's driver fires the retire unit on the first `live() == 0`
// pass; `__retire` is what keeps `| stopped` honest — "a running server was
// asked to stop" answers `stopped` (and tears the listener down); "the
// machinery never stood up" answers `silent`, so a failed init doesn't get to
// claim a shutdown that never happened. `__` marks generated-machinery
// vocabulary — consumers never spell it.

pub tor __retire {}
| ?stopped
| ?silent

// ============================================================================
// PARTICIPANT VERBS — the same lifecycle, decomposed for std/pump
// ============================================================================
// `init` owns the machinery: listener, TLS context, worker kqueues, accept
// threads. `! arrived` arms here — the workers it spawns are what fire it.
// `step` is one pass of the accept loop: drain pending connections, hand each
// to a worker round-robin, return how many were taken. Connection readiness
// never reaches this level — it lives inside the workers' kqueues, which are
// participant-internal. `wait` is the listener fd alone; `live` is
// "started and not stopped" — a failed init never joins the pump; `stop` asks
// the server to retire at the next liveness check.

pub tor init { port: u16, tls_port: ?u16, cert_path: ?string, key_path: ?string }
! arrived *Exchange
! frame *Exchange
! closed usize
| ?started
| failed string

pub tor step {} -> i32

pub tor live {} -> i64

pub tor wait { i: i64 } -> { fd: i32, wait_ns: i128 }

pub tor stop {}

pub tor deinit {}

// ============================================================================
// FILL — get more bytes into a connection's buffer
// ============================================================================
// The mirror of `reply`. Writing has had a platform seam since the unikernel
// arrived; reading did not, and each loop called the socket itself — three
// spellings of one contract, with nothing in between the wire and the request
// parser. This is that in-between.
//
// The three branches are the three answers, and `idle` is the one the old code
// could not say. `posix.read` reports "nothing right now" as an error, which the
// loops caught and turned into zero bytes — the same value a peer that hung up
// produces. A connection that merely had nothing to say was therefore
// indistinguishable from one that had gone away.
//
// It is also the seam a transport layer needs. Encryption consumes bytes from
// the wire while producing none for the parser — a handshake is exactly `idle`
// — and there is no way to express that when the loop reads straight into the
// buffer the request parser reads out of.
//
// @retain: called from the run bodies' raw Zig via $mod.fill_event.handler(...),
// which the dead-stripper cannot see — the same reason orisha:handler is
// retained.

[retain]pub tor fill { st: *ConnState }
| more
| idle
| gone

// ============================================================================
// REPLY — write an answer back
// ============================================================================
// `head` and `body` go out in that order; a caller that already holds a whole
// rendered response passes it as `head` with an empty `body`, which is what a
// pre-rendered static route does. `hang` is the handler's `Response.close`
// carried through `answer` — named for `hang-up` because a bare `close`
// shadows libc's own decl inside the emitted module: the reply goes out and
// the connection does not stay — on a 101 the body lands as the first frame,
// a close frame follows, and the pump reaps, so a protocol can refuse a
// socket cleanly.

pub tor reply { x: *Exchange, head: string, body: string, date_hole: usize, head_static: bool, body_static: bool, hang: bool }
| sent
| broken string

// ============================================================================
// WS-SEND / WS-CLOSE — the websocket write side
// ============================================================================
// Only meaningful inside a `! frame` arm, on a connection a 101 answer already
// upgraded: `ws-send` emits one unmasked frame, `ws-close` a close frame plus
// the hang-up. `opcode` absent means echo what was dispatched — `x.opcode`
// carries it (0x1 text, 0x2 binary); 0 falls back to text. A broken write is
// reported the same way `hang-up` reports it — the pump reaps the connection
// when the arm returns, so there is no `| broken` to spell.

pub tor ws-send { x: *Exchange, payload: string, opcode: ?u8 }

pub tor ws-close { x: *Exchange }

// ============================================================================
// WS-SEND-FD — write one frame to a connection named by descriptor
// ============================================================================
// `ws-send` can only answer the frame currently being dispatched. A broadcast
// — a pub/sub channel, a heartbeat, a server push — must reach an upgraded
// connection while it is IDLE in the readiness loop, on whatever thread is
// doing the sending. `fd` is the integer `fileno` reported; the pump still
// owns the descriptor and remains the only writer — the flow names the
// target, the pump frames and sends.
//
// The answer is `sent`, or `gone` when no upgraded connection carries that fd
// — a registry that hears `gone` forgets the entry. Writes on one connection
// are serialized inside the pump: a `ws-send` in a frame arm and a
// `ws-send-fd` from a pusher thread cannot interleave bytes mid-frame, and a
// send that races a release waits rather than writing into freed state.

pub tor ws-send-fd { fd: usize, payload: string, opcode: ?u8 }
| sent
| gone

// ============================================================================
// WS-CLOSED — the pump is reaping an upgraded connection
// ============================================================================
// Fires once per upgraded connection when the pump releases it — close
// handshake, protocol violation, hang-up, idle eviction, or server stop.
// `fd` is the descriptor a registry must forget; it is passed by value
// because the Exchange is already dead by definition. The default is a no-op:
// a websocket claimant that tracks no connections is not forced to implement
// it. Abstract so a claimant can implement it; the companion's empty default
// means a websocket app that tracks no connections is unaffected either way.
// @retain: dispatched from the release path in raw Zig, invisible to the
// dead-stripper for the same reason `fill` is.

[abstract|retain]pub tor ws-closed { fd: usize }

// ============================================================================
// WS-FRAME — a complete websocket message on an upgraded connection
// ============================================================================
// Abstract like orisha:handler — serve's `! frame` arm routes every complete
// message here and the default drops it; a claimant implements the tor to do
// something with them. `f.raw` is the reassembled payload and `f.opcode` is
// 0x1 text or 0x2 binary. Ping, pong and close never reach the arm — the
// pump answers control frames at the seam.
//
// It is not spelled `frame` because `! frame` lowers to a zig symbol named
// `frame` — the same fate `arrived` has — and a tor with that name would
// collide with the arm's own callback in the emitted file.

[abstract|retain]pub tor ws-frame { f: *Exchange }

// ============================================================================
// HANG-UP — refuse to keep the connection
// ============================================================================
// The pump closes it when the arm returns.

pub tor hang-up { x: *Exchange }

// ============================================================================
// FILENO — the connection's descriptor, for ownership handoff
// ============================================================================
// The one bridge a long-lived connection needs: an arm that wants work to
// OUTLIVE itself (a pusher thread, a background writer) cannot hand over the
// exchange — the pump owns it and closes it when the arm returns. It hands
// over a DUPLICATED descriptor instead, and `fileno` is how the flow reaches
// it. The caller dups before spawning; from that moment the pump closing its
// copy is irrelevant to the thread's copy. Ownership moves; nothing is shared.

pub tor fileno { x: *Exchange } -> usize

// ============================================================================
// RAW — the request bytes, for the parsing layer
// ============================================================================
// An OWNED copy, not a borrow: `x.raw` lives in the pump's read buffer, and a
// `->` return may not hand back a borrow of its parameter (610_007). The copy
// lives in a per-request arena in the companion that resets on the next call —
// after the current arm is fully answered — and every source of `Exchange.raw`
// is a slice of `ConnState.buf`, so the copy always fits. Implemented in Zig
// beside the arena; there is no Koru-level projection to refuse.

pub tor raw { x: *Exchange } -> string
