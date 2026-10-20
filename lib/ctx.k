// Orisha's request context — the contract.
//
// What a ctx is: the request-scoped scratch a handler's flow needs while it
// runs. Two halves, both request-shaped:
//
//   cells    named slots for values that must cross a `! row`-arm boundary.
//            A row arm fires once per row and cannot produce the enclosing
//            tor's terminal, so a value the `| done` continuation needs has
//            to ride something that outlives the arm. That something is a
//            cell: `ctx:set-int`/`ctx:set-text` inside the arm, `ctx:int`/
//            `ctx:take-*` after it.
//
//   body     the outgoing-body accumulator. A handler produces ONE response
//            but a `! row` arm fires per row, so fragments fold into the
//            buffer and `ctx:body-take` hands the finished page out.
//
// Why there is no Request handle on any of these: orisha workers are
// single-threaded and a handler runs to completion, so at most one request's
// context is live on a thread at a time — the cells and buffers are
// threadlocal in the companion and request-scoped by construction. The
// thread locality is the implementation's business; nothing here ever asks
// a caller to think about it.
//
// Cell semantics:
//   - names are looked up per call over a small fixed table (24 int cells,
//     16 text cells). Name collisions across an app's modules share a cell —
//     pick per-purpose names ("session.uid", not "uid").
//   - text cells hold at most 2048 bytes. `set-text` stores the WHOLE value
//     and answers `ok`; when the value doesn't fit it stores a 2048-byte
//     prefix and answers `truncated` — the branch is the record that it
//     happened, never a silent chop.
//   - `take-*` reads the cell and clears it; `int`/`text` read without
//     clearing. A cell with nothing stashed answers null (or `default` on
//     the `-or` spellings — the caller's sentinel, not ours).
//   - `ctx:clear` wipes every cell. Call it at a request head if your flow
//     leaves cells untaken; `ctx:begin` does NOT clear cells — a csrf stash
//     primed before the first `begin` must survive it.
//
// Usage:
//   ! row r |> db:col.int(stmt: r, index: 0): u |> orisha/ctx:set-int(name: "app.uid", v: u)
//   | done d |> orisha/ctx:take-int-or(name: "app.uid", default: 0): uid |> if(uid > 0) ...

pub tor set-int { name: string, v: i64 }
pub tor int { name: string } -> ?i64
pub tor int-or { name: string, default: i64 } -> i64
pub tor take-int { name: string } -> ?i64
pub tor take-int-or { name: string, default: i64 } -> i64

pub tor set-text { name: string, v: string<*> }
| ok
| truncated

pub tor text { name: string } -> ?string
pub tor take-text { name: string } -> ?string

pub tor clear {}

// ============================================================================
// BODY — the outgoing-body accumulator
// ============================================================================
// `begin` resets the body AND fragment buffers — call it once at a page's
// head, before anything writes. Fragments get their own buffer because
// `body-take` returns a live slice of `buf`: rows folded into `buf` then
// embedded in a component would dangle (and double — once raw, once inside
// the component). `frag-write`/`frag-take` are that second accumulator.
//
// `body-take`'s answer borrows the buffer — it dies at the next `begin`.
// That is the whole lifetime contract, and it is long enough: the response
// is built and handed to the pump before the next request's `begin` runs
// on this worker.

pub tor begin {}
pub tor body-write { text: string<*> }
pub tor body-take {} -> string
pub tor frag-write { text: string<*> }
pub tor frag-take {} -> string
pub tor has-content {} -> bool

// 200 when the buffer holds a page, 204 when it's empty — the controller's
// `head :no_content` on an empty collection. `body-status-or` is the same
// verdict with the caller's empty status: a room-show empty means 404
// (missing room / non-member), not 204.
pub tor body-status {} -> u16
pub tor body-status-or { status: u16 } -> u16
