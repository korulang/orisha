// Orisha's pump — the contract.
//
// What a pump is: the thing that owns the readiness loop and hands the flow one
// exchange at a time. Every declaration is here; the loop bodies, one per
// platform, are in the companion `pump.kz`. This file has no host language in
// it, so it has no `~` in it either.

// TLS helpers live in koru/openssl; imported from orisha/index.k so emission
// orders koru_openssl before this submodule in the merged module.

// ============================================================================
// RUN — the loop. One variant per platform.
// ============================================================================
// `! arrived` fires once per request and RESUMES; `| stopped` and `| failed`
// are the two ways the loop ends. `*Exchange` is a host type the companion
// declares — a contract may name one, it just may not define one.

pub tor run { port: u16, tls_port: ?u16, cert_path: ?string, key_path: ?string }
! arrived *Exchange
| stopped string
| failed string

// ============================================================================
// PARTICIPANT VERBS — the same lifecycle, decomposed for std/pump
// ============================================================================
// `init` owns the machinery: listener, TLS context, worker kqueues, accept
// threads. `! arrived` arms here — the workers it spawns are what fire it.
// `step` is one pass of the accept loop: drain pending connections, hand each
// to a worker round-robin, return how many were taken. Connection readiness
// never reaches this level — it lives inside the workers' kqueues, which are
// participant-internal. `wait` is the listener fd alone; `live` is `!stop`;
// `stop` asks the server to retire at the next liveness check.

pub tor init { port: u16, tls_port: ?u16, cert_path: ?string, key_path: ?string }
! arrived *Exchange
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
// pre-rendered static route does.

pub tor reply { x: *Exchange, head: string, body: string }
| sent
| broken string

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
