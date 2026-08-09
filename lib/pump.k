// Orisha's pump — the contract.
//
// What a pump is: the thing that owns the readiness loop and hands the flow one
// exchange at a time. Every declaration is here; the loop bodies, one per
// platform, are in the companion `pump.kz`. This file has no host language in
// it, so it has no `~` in it either.

// ============================================================================
// RUN — the loop. One variant per platform.
// ============================================================================
// `! arrived` fires once per request and RESUMES; `| stopped` and `| failed`
// are the two ways the loop ends. `*Exchange` is a host type the companion
// declares — a contract may name one, it just may not define one.

pub tor run { port: u16 }
! arrived *Exchange
| stopped string
| failed string

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
// RAW — the request bytes, for the parsing layer
// ============================================================================
// Implemented right here, in Koru, because there is nothing host-shaped about
// reading a field.

pub tor raw { x: *Exchange } -> string
raw -> x.raw
