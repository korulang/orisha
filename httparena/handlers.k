// HttpArena route bundle — NOT part of the public Orisha API.
//
// The handlers are implemented in Koru: request parsing, arithmetic,
// response shapes, and content negotiation are flows the compiler emits.
// Zig lives only in the stdlib and framework primitives these flows call
// (string ownership, I/O, compression) — there is no Zig in this module.

import orisha
import std/string
import std/fmt
import std/json
import std/compress
import std/env
import std/fs
import std/store

pub tor baseline { req: *orisha:Request } -> orisha:Response
pub tor json { req: *orisha:Request, count: string } -> orisha:Response

// The dataset's process-lifetime home. Each row is one item's wire view —
// every byte the response carries except the request-scoped `total` — held
// as an owned String beside that item's price*quantity base. orisha:init
// fills it once, before the pump's workers exist; /json sweeps views of it
// per request. Capacity is the app's declared bound on dataset size: a
// dataset past it fails init rather than serving a partial view.
std/store:new(dataset, capacity: 4096) { frag: *std/string:String<std/string:instance!>, base: i64 }

// The seeded row count, so /json clamps a request's count against custody
// without sweeping to learn it.
std/store:new(dsmeta) { n: 0[i64] }

// ?string -> string: an absent param is "" and reads as 0.
tor or-empty { s: ?string } -> string
or-empty -> s orelse ""

tor finish { n: i64 } -> i64
finish -> n

// "" and non-numeric input both read as 0 — the contract is the sum.
tor int-of { text: string } -> i64
int-of = if(text.len == 0)
| then -> 0
| else |> std/string:from-page(text)
    | ok s |> std/string:parse-int(s)
        | ok n |> std/string:free(s) |> finish(n): r -> r
        | err _ |> std/string:free(s) |> finish(n: 0): r -> r
    | err _ -> 0

tor prod2 { a: i64, b: i64 } -> i64
prod2 -> a * b

tor clamp-count { want: i64, len: usize } -> usize
clamp-count = if(want <= 0)
| then -> 0
| else |> if(@as(usize, @intCast(want)) > len)
    | then -> len
    | else -> @as(usize, @intCast(want))

tor respond-int { n: i64 } -> orisha:Response
respond-int = std/fmt:ln("{{ n:d }}"): l -> { status: 200, body: l.text, content_type: "text/plain" }

tor respond-plain { body: string } -> orisha:Response
respond-plain -> { status: 200, body, content_type: "application/json", body_allocated: true }

tor respond-gz { body: string } -> orisha:Response
respond-gz -> { status: 200, body, content_type: "application/json", content_encoding: "gzip", body_allocated: true }

tor respond-error {} -> orisha:Response
respond-error -> { status: 500, body: "internal error", content_type: "text/plain" }

// a + b from the query string, plus a bare integer body when the request
// carries one — GET sends no body, so `body` reads null and contributes 0.
baseline = orisha:query-param(req, name: "a"): qa
|> or-empty(s: qa): atxt
|> orisha:query-param(req, name: "b"): qb
|> or-empty(s: qb): btxt
|> orisha:body(req): bd
|> or-empty(s: bd): bdtxt
|> int-of(text: atxt): an
|> int-of(text: btxt): bn
|> int-of(text: bdtxt): bdn
|> respond-int(n: an + bn + bdn): r -> r

// The dataset file wrapped as {"items":[...]} — the file itself supplies
// the top-level array, so the wrapper only names it: prepend `{"items":`,
// append `}`. read-lines streams the lines into one buffer; joining
// without separators is safe because JSON whitespace is insignificant.
tor read-dataset { path: string }
| ok *std/string:String<view>
| failed string

read-dataset = std/string:from-page(text: "{\"items\":")
| ok fb |> std/string:take(s: fb): filebuf
    |> std/fs:read-lines(path)
        ! line l |> std/string:append(s: filebuf, text: l)
            | ok |> _
            | err _ |> _
        | done _ |> std/string:append(s: filebuf, text: "}")
            | ok |> std/string:release(s: filebuf): fv => ok fv
            | err _ |> std/string:free(s: filebuf) => failed "join failed"
        | failed e |> std/string:free(s: filebuf) => failed e
| err _ => failed "allocation failed"

// One dataset item's wire view, rendered ONCE at init through the same
// schema-directed emit the response used to pay per request: the full item
// emitted with a placeholder `total: 0`, kept up to `"total":` — the
// request's multiplier is the only byte that varies. The leading comma is
// baked in so the sweep appends rows with no separator state.
tor mint-frag { id: i64, name: string, category: string, price: i64, quantity: i64, active: bool, tags: []string, score: i64, count: i64 }
| ok
| failed string

// The placeholder's trailing `0}` comes off by substring, not pop-char —
// a failed realloc shrink would leave `0}` attached and there is no err
// arm on pop-char to catch it. Emit's `out` is `<emitted!>`-qualified, so
// it goes in by append (the `string<*>` surface) before emit.free discharges.
mint-frag = prod2(a: price, b: quantity): base
|> std/json:emit(value: { id, name, category, price, quantity, active, tags, rating: { score, count }, total: 0 }): out
|> std/string:from-page(text: ",")
| ok comma |> std/string:take(s: comma): raw
    |> std/string:append(s: raw, text: out)
    | ok |> std/json:emit.free(text: out)
        |> std/string:len(s: raw): elen
        |> std/string:substring(s: raw, start: 0, end: elen - 2)
            | ok sub |> std/string:take(s: sub): frag
                |> std/string:free(s: raw)
                |> std/store:insert(dataset) { frag, base }
                | row _ => ok
                | full _ => failed "dataset exceeds store capacity"
            | err _ |> std/string:free(s: raw) => failed "substring failed"
    | err _ |> std/json:emit.free(text: out) |> std/string:free(s: raw) => failed "append failed"
| err _ |> std/json:emit.free(text: out) => failed "alloc failed"

// Per request, per row: the stored fragment, the request-scoped total,
// the closing brace. fmt:ln renders into a thread-local buffer — the
// append copies it out before the next call reuses it. The row bound is
// gated inside the body, not the arm's `when`: the guard is emitted in
// the loop's scope where a requested `[ordinal]` name does not exist —
// the ordinal only materializes as a sweepbody input.
tor emit-custody { frag: *std/string:String<instance>, base: i64, buf: *std/string:String<instance>, m: i64, n: usize, i: i64 }
emit-custody = if(i < @as(i64, @intCast(n)))
| then |> prod2(a: base, b: m): t
    |> std/fmt:ln("{{ t:d }}"): l
    |> std/string:append(s: buf, text: frag.data)
        | ok |> std/string:append(s: buf, l.text)
            | ok |> std/string:append(s: buf, text: "}")
                | ok |> _
                | err _ |> _
            | err _ |> _
        | err _ |> _

// Parse the wrapped dataset once and seed custody: each item's fragment
// into `dataset`, the row count into `dsmeta`.
tor seed-dataset { ds: *std/string:String<view> }
| ok
| failed string

seed-dataset = std/json:parse(input: ds.data)
| malformed _ => failed "dataset malformed"
| ok { items: []{ id: i64, name: string, category: string, price: i64, quantity: i64, active: bool, tags: []string, rating: { score: i64, count: i64 } } }
    |> for(items)
        ! each it |> mint-frag(it.id, it.name, it.category, it.price, it.quantity, it.active, it.tags, it.rating.score, it.rating.count)
            | ok |> _
            | failed e => failed e
        | done |> std/store:stored { dsmeta.n: @as(i64, @intCast(items.len)) } => ok

// The app-level init hook: DATASET_PATH is read and rendered into custody
// a single time, on the thread that calls serve, before a worker exists.
orisha:init = std/env:get.or(name: "DATASET_PATH", default: "/data/dataset.json"): path
|> read-dataset(path)
    | ok ds |> seed-dataset(ds)
        | ok |> std/string:free(s: ds) => ready
        | failed e |> std/string:free(s: ds) => failed e
    | failed e => failed e

// Content negotiation on the finished body: deflate through std/compress
// when the request accepts gzip, the plain owned body otherwise. Both
// paths hand the Response an owned slice — `body_allocated` frees it
// after send — and `env` is discharged exactly once on every arm.
tor negotiate { env: *std/string:String<!instance>, ae: string } -> orisha:Response
negotiate = std/string:from-page(text: ae)
| ok aeh |> std/string:contains(s: aeh, needle: "gzip")
    | yes |> std/string:free(s: aeh) |> std/compress:gzip(env.data)
        | compressed c |> std/string:free(s: env) |> respond-gz(body: c.data): r -> r
        | error _ |> std/string:detach(s: env): body |> respond-plain(body): r -> r
    | no |> std/string:free(s: aeh) |> std/string:detach(s: env): body |> respond-plain(body): r -> r
| err _ |> std/string:detach(s: env): body |> respond-plain(body): r -> r

// Close the envelope: `],"count":N}` — `env` arrives consumed.
tor finish-envelope { env: *std/string:String<!instance>, ae: string, n: usize } -> orisha:Response
finish-envelope = std/string:from-int(n: @as(i64, @intCast(n)))
| ok nstr |> std/string:append(s: env, text: "],\"count\":")
    | ok |> std/string:append(s: env, text: nstr.data)
        | ok |> std/string:append(s: env, text: "}")
            | ok |> std/string:free(s: nstr) |> negotiate(env, ae): r -> r
            | err _ |> std/string:free(s: nstr) |> std/string:free(s: env) |> respond-error(): r -> r
        | err _ |> std/string:free(s: nstr) |> std/string:free(s: env) |> respond-error(): r -> r
    | err _ |> std/string:free(s: nstr) |> std/string:free(s: env) |> respond-error(): r -> r
| err _ |> std/string:free(s: env) |> respond-error(): r -> r

// The items buffer holds ",{item},{item}" — a leading comma per element,
// so no separator state crosses iterations. Slicing it off is one
// substring; an empty loop leaves the buffer empty and the count is 0.
tor items-open {} -> string
items-open -> "{\"items\":["

tor respond-json { obuf: *std/string:String<!instance>, ae: string, n: usize } -> orisha:Response
respond-json = std/string:len(s: obuf): olen
|> items-open(): op |> std/string:from-page(text: op)
| ok es |> std/string:take(s: es): env
    |> if(olen == 0)
        | then |> std/string:free(s: obuf) |> finish-envelope(env, ae, n): r -> r
        | else |> std/string:substring(s: obuf, start: 1, end: olen)
            | ok sub |> std/string:append(s: env, text: sub.data)
                | ok |> std/string:free(s: sub) |> std/string:free(s: obuf) |> finish-envelope(env, ae, n): r -> r
                | err _ |> std/string:free(s: sub) |> std/string:free(s: obuf) |> std/string:free(s: env) |> respond-error(): r -> r
            | err _ |> std/string:free(s: obuf) |> std/string:free(s: env) |> respond-error(): r -> r
| err _ |> std/string:free(s: obuf) |> respond-error(): r -> r

// The sweep as its own tor: `std/store:query` is a transform site, so a
// trailing `| done`/`|>` continuation written against it never emits —
// the body call must end the flow. Naming the sweep lets the caller's
// chain continue past it, and its tor inputs ride the sweep's capture
// threading into the body.
tor sweep-custody { buf: *std/string:String<instance>, m: i64, n: usize }
sweep-custody = std/store:query(dataset)
! query { [row]it, [ordinal]i }
    |> emit-custody(it.frag, it.base, buf, m, n, i)

// Serve views of the custody: buffer an empty String, sweep the seeded
// rows into it (each append is fragment + total + `}`, gated on the
// row's ordinal being under the request's clamped count), then wrap.
tor serve-items { m: i64, want: i64, ae: string } -> orisha:Response
serve-items = clamp-count(want, len: @as(usize, @intCast(dsmeta.n))): n
|> std/string:from-page(text: "")
| ok os |> std/string:take(s: os): obuf
    |> sweep-custody(buf: obuf, m, n)
    |> respond-json(obuf, ae, n): r -> r
| err _ |> respond-error(): r -> r

json = orisha:query-param(req, name: "m"): qm
|> or-empty(s: qm): mtxt
|> int-of(text: mtxt): m
|> int-of(text: count): want
|> orisha:header(req, name: "accept-encoding"): ah
|> or-empty(s: ah): ae
|> serve-items(m, want, ae): r -> r
