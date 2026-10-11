---
type: belief
id: frag-serialize-the-invariant-render-the-variant
provenance: HttpArena json-tls work, 2026-10 — perf under wrk showed ~27% of CPU in Io.Writer dispatch; cursor+prefix form dropped it below the noise floor
ts: 2026-10-07
---

# Serialize the invariant once; render the variant live (belief)

A response body that is mostly dataset-constant should not be re-serialized
through a generic writer per request. `writeJsonItem` formatted ten
arguments through `Io.Writer` per item — type-erased calls, alignment logic,
format-string interpretation — for bytes that never change. Measured: ~27%
of all samples under json-tls load, larger than kernel AES-GCM (2.9%) by an
order of magnitude.

The correct split is the request-dependence boundary, not the field boundary:
everything before `"total":` is a per-item constant (prefix slice built once
in `ensureCache`), and the only live render is `price*quantity*m` plus the
closing brace. This stays inside HttpArena's rules — the `?m=N` parameter
exists to defeat whole-response caching, and the response still varies with
both `count` and `m`; it is the same class of pre-serialization `CachedItem`
already used for `name_json`/`tags_json`.

## What the instrument said

json-tls best-of-3: ~34-36.6K before → 37.9-41.4K after; post-change perf
shows the writer symbols below the 1.5% floor entirely. The verification
that could have falsified it — a byte-exact diff of the serialized body
against the previous binary — passed on both cleartext and TLS.

## What the instrument said — second pass (2026-10-08)

The residual `memcpy` was not one copy but two: `body_work` → `http_out`
(`finishHttp` re-printing the finished body) → `send_buf` (`appendPending`).
Since `Content-Length` is computable before writing — the body is prefix
lengths plus decimal widths — the head can land at offset 0 and the body
directly behind it: one contiguous wire message, rendered once. The
`body_work → http_out` pass is gone; `appendPending`'s copy into `send_buf`
is the only one left and it exists for pin safety while a send SQE is in
flight. `send_buf` growth is now doubling-with-floor instead of exact-size,
so a conn's buffer stops reallocating on every larger response (the
`clear_page_erms` term).

Local verification on LinuxKit (no kTLS — the mem-BIO leg): 30/30
`(count, m)` responses byte-identical to the previous binary, 60/60
semantically checked against the dataset (live `total` per `m`), gzip path
unchanged, cleartext + TLS pipelined/keep-alive/close all correct. A wrk
A/B through docker-proxy showed no resolvable delta — laptop timing cannot
falsify this change; the droplet run is the instrument.

## What the instrument said — third pass (2026-10-08)

The last copy fell too. `Request.fd` names the conn; `ringRenderTarget(fd,
len)` in pump.kz looks it up and — when the conn is ring-owned, non-ws,
non-TLS, with no send SQE in flight — returns `send_buf[send_staged..]` as
the render destination (growing it first). The renderer writes the wire
message there directly and `appendPending` claims the span by pointer
match, no memcpy. The Date splice would have displaced the span (the
middle segment is external), so `jsonResponse` embeds the line itself via
`httpDateLine()` and the baked-head contract learned that a `Date:` already
at the splice point means `date_hole = 0` — identical wire bytes, one
unspliced segment.

A counter probe under wrk showed 217,089/217,927 json responses claimed
without copy (~all; the delta is warmup traffic). Guards that refuse the
target — send in flight, ws mode, live mem-BIO SSL — keep the unsafe cases
on the copying path; a pipelined batch accumulates several rendered
responses into `send_buf` contiguously and ships them in one send SQE.

The earlier droplet A/B (second-pass binary vs its parent, same host,
alternating): +4–10% best-of-3 on baseline/pipelined/jsoncomp, jsontls
flat — inside that droplet's noise floor. The zero-copy response path
itself is verified by the claim counter and the battery, not by stopwatch:
its throughput effect is unmeasured.

## What the instrument said — fourth pass (2026-10-08)

The recv side got the same treatment. Cleartext conns now arm one
multishot recv over a plain provided-buffer ring (1024 × 8K per worker,
group 1) for the conn's whole life — no per-CQE SQE prep, and reads keep
arriving while a send SQE is in flight. The CQE names a buffer id, not a
destination; bytes are copied into `st.buf` (older `recv_hold` overflow
first, so pipelined ordering stays a stream invariant) and the pool
buffer is recycled immediately.

Two structural consequences:

- **Teardown is two-step.** The op outlives the conn's interest — its
  terminal CQE still dereferences `ConnState` through `user_data`. So
  teardown detaches the table slot and closes the fd at once (a reissued
  descriptor meets fresh state, and close() retires the armed recv), but
  the struct is freed only when `recv_armed` is false and no send is in
  flight.
- **Multishot requires O_NONBLOCK.** On a blocking fd the kernel retires
  the op at the first delivery — it cannot wait for more without a poll
  arm. `markNonBlocking` now applies to cleartext accepts too. Verified
  by CQE flags `0x13` (`F_BUFFER|F_MORE|F_BUF_MORE`): the op stays armed
  across deliveries, confirmed on both debug and ReleaseFast builds.
  std's `IoUring.BufferGroup` was deliberately not used — it registers
  an incremental ring with different delivery semantics; a plain
  `setup_buf_ring` keeps each CQE = one fresh buffer.

TLS conns keep single-shot recvs into `tls_in` — the ciphertext buffer
is theirs and the pool is cleartext-only. If the kernel refuses the pool
(pre-5.19, tiny `RLIMIT_MEMLOCK`) the conn falls back to one-shot
`st.buf` recvs; `-ENOBUFS` mid-life retires the op without losing bytes
and `advance` re-arms.

Verified on LinuxKit: pool armed on all 12 workers, multishot CQE path
confirmed live; 60/60 semantic vs dataset, 4-response pipelined batch in
order, keep-alive burst, `Connection: close` EOF, 50-conn storm, TLS
single/pipelined/close all correct, ~514K requests under wrk with the
server alive and RSS ~51MB. Throughput effect: unmeasured — the local
docker-proxy transport cannot falsify it; a droplet A/B is the
instrument.

## What the instrument said — fifth pass (2026-10-08)

The droplet A/B exposed two bugs the local battery missed, then measured.

**The collapse was a use-after-free, not flow control.** Under `-r 25`
conn churn the new build died intermittently: connect-error storms while
established conns kept serving. Local repro needed send-then-close-
immediately clients to fire it. Core dump: `maybeFreeRing` ran
`st.ws_mu.lock(); defer st.ws_mu.unlock(); closeConnMem(st); destroy(st)`
— the defer evaluated `st.ws_mu` on freed memory. Debug's mutex
owner-assert panicked (`unreachable`, trace destroyed by a panicking
panic-handler); ReleaseFast silently corrupted the heap. Two adjacent
defects fixed in the same pass: `bg.release` was gated on `res > 0`,
leaking a pool buffer per terminal `F_BUFFER` CQE; and `-ENOBUFS` now
parks the conn on one-shot recvs (`ms_off`) instead of an arm→ENOBUFS
re-arm spin.

**Post-fix interleaved A/B (c-4 pair, gcannon/wrk, 3 rounds each):
baseline tie (~165K), pipelined tie (1.17–1.21M), jsontls tie (~55K),
jsoncomp loss — new 28.7–30.6K vs prev 31.2–34.9K, ~8–10% behind on the
churn profile.** The mechanism as built is a small loss, not a win:
every conn close pays a second CQE pass (the armed recv's terminal CQE
runs teardown→free again after close()), and each recv batch pays a
pool-buffer→`st.buf` copy the one-shot path never had — recv directly
into `st.buf` was free. The saved re-arm does not cover the extra
teardown pass under conn churn.

The open question is settled in the negative direction: multishot recv
on this shape — copy into `st.buf`, deferred free — loses on the profile
it was meant to help. A win requires dispatch to run on the pool buffer
directly (zero recv-side copy) and the terminal-CQE pass to do less.

## What the instrument said — sixth pass (2026-10-10)

The named surgery landed: `dispatchHttpSlice` runs the request loop on
whatever buffer holds the bytes, and `msRecvCqe` calls it on the checked-out
pool buffer whenever nothing is pending (`st.len == 0`, `recv_hold` empty,
non-ws, not already dead). Only a request straddling the buffer's end parks
its tail in `st.buf`; `x.raw`'s borrow contract is unchanged — the pool
buffer is released to the ring only after `arrived()` returns, so the kernel
cannot overwrite bytes mid-parse.

A correctness trap surfaced that the copy path had masked: dispatch can now
set `ring_dead` *before* the terminal-`res` check, and `teardown()` closes
the fd without draining — a `Connection: close` request went out as EOF
with no response. `pre_dead` splits the cases: death on arrival tears down
immediately (and skips dispatch entirely, as before), death during dispatch
falls through to `advance()`, which flushes the staged response then closes.
The same trap was latent in the old code's `drainRecvHold` path.

Correctness: HttpArena `validate.sh orisha` — **37/37 pass** including the
1047-offset fragmentation suite, pipelined batches, gzip negotiation, and
TLS 1.3 quality; plus hand-verified split-request, same-write pipelining,
and close-then-EOF. Throughput: **unresolved.** wrk showed +15–25% at
-c64/-c512; gcannon (the board's own generator class) showed deltas inside
the ±10% run-to-run noise of the LinuxKit VM — this box cannot price a
change whose expected effect is single-digit percent. The same-box zix A/B
(orisha +25–30% interleaved on baseline, +65% on gzip-json) is the stronger
datum but says nothing about this specific change. A quiet-hardware A/B —
droplet pair or the board — is the instrument.

## What the instrument said — seventh pass (2026-10-10, droplet)

Priced on quiet hardware: a dedicated `c-4` pair in sfo3 (server
`24.199.101.245`, gcannon load `209.38.75.119` over private LAN, steal 0%),
`3848955` vs `00ded44` interleaved 4 rounds each profile.

The methodological finding comes first, because without it the run reads as
a wash: **on a 4-vCPU pair the generator saturates before the server in every
default profile.** Baseline `-p1 -c512` pinned flat at ~168K regardless of
conn count (round-trip bound, server ~53% busy); `-p16` reached 1.09–1.35M
with the server at ~31–34%; churn `-r10` at ~120K. Throughput-identical A/B
in that regime measures the client, not the server — the earlier "±10%
noise" was really "zero sensitivity." The discriminating regime was made by
`taskset -c 0` on the server process: one core, provably saturated (25% of
total = 100% of one), while the generator retains headroom.

Under that regime, four interleaved rounds of the board's own pipelined
profile (`-p16 -c512`, the load where each recv batch carries up to 16
requests and the removed copy is largest):

- `00ded44`: 1.03M, 1.01M, 0.975M, 1.02M — mean ~1.01M rps
- `3848955`: 0.956M, 0.872M, 0.895M, 0.866M — mean ~0.897M rps
- **+12.6% mean, non-overlapping distributions** (min-new 0.975M > max-prev
  0.956M); gcannon latency corroborates (avg 8.13ms vs 9.39ms, −13%);
  ~88M responses, zero errors.

Profiles where the patch's mechanism doesn't engage priced at parity, which
is the expected shape rather than a disappointment: json-gzip at 4 cores
(server-bound at 99%, deflate-dominated) ~73.9K vs ~73.8K; TLS json at 1
core (ciphertext still takes the copy path into the mem-BIO) ~52.6K vs
~52.7K. Churn `-r10` stayed generator-bound at ~120K both — the
terminal-CQE teardown cost is real but unpriced by this instrument.

Verdict on the change: keep it. The removed copy is worth ~+12% on the
profile where it applies, zero elsewhere measured. The board's pipelined
score measures server saturation with a loadgen that doesn't cap first, so
this delta is the honest estimate of what the change buys there.

## What the instrument said — eighth pass (2026-10-10, single-pass scan)

The first same-harness race (c-4, `benchmark.sh`, archived under
`benchmarks/arena-race-2026-10-10/`) named the remaining deficit: zix took
the pipelined profile 2.15M vs 1.23M while orisha burned *more* CPU for it
(208% vs 155%) — a structural per-request cost, not a generator artifact.
Perf under `-p16` put `mem.indexOfPos` near the top of the profile: each
dispatched request had its header block scanned up to five times — the
`\r\n\r\n` terminator search, `Content-Length`, `Transfer-Encoding`,
`Connection`, then the real parse in `arrived()`.

The surgery follows the same belief as every pass before it — walk the
bytes once: a single `scanRequest` pass computes frame length and
`Connection: close` together, replacing `requestLen` +
`requestWantsClose` at all five dispatch sites.

Correctness: all five semantic classes hand-probed byte-identical old vs
new (split headers, same-write pipelining, `Connection: close` +
flush-then-EOF, `Content-Length` body + pipelined successor, chunked body
+ successor); ~163M pipelined responses under `-p16 -c512`, zero non-2xx;
duplicate-header and malformed-`Content-Length` edge probes identical
old vs new (first-match-wins semantics preserved via seen-flags).
HttpArena `validate.sh orisha`: **37/37 pass** on the final code,
including the 1047-offset fragmentation suite.

Mechanism confirmed by same-load perf: `indexOfPos` 10.66% → 6.39%,
`dispatchHttpSlice` 6.26% → 2.96%, `arrived` flat at ~8.5% — the front-end
trio dropped ~26% → ~18% of samples. Throughput: **unpriced** — the
LinuxKit VM is generator-bound (interleaved rounds overlap: old
2.45/2.60/2.74M, new 2.28/2.66/2.67M); an earlier single-shot 4.07M vs
1.99M was discarded as a warm-up artifact per the surprise-freeze rule.
The board's pipelined score, or another single-core-pinned droplet, is the
instrument that prices it. `arrived()`'s own re-parse is now the largest
remaining front-end cost — the third scan made visible by removing the
first two.

## What the instrument said — ninth pass (2026-10-10, the audit)

This frag's own thesis, applied inside the benchmark entry, was the one
thing over the line. `CachedItem.prefix` serialized each dataset item's
invariant bytes once at startup and per-request rendered only the `total`
digits — "serialize the invariant once" taken literally. The front-runner
(zix) draws the line explicitly in its own description: *"No response
cache and no startup pre-serialization anywhere."* Their handler routes
every field through a general serializer (jzon) per request.

Removed before submission. The entry now serializes `{"items":[...],
"count":N}` per request through `std.json.Stringify` into the back of
the staging span (HEAD_RESERVE front-room for the head), zero memoized
bytes; gzip path serializes into threadlocal scratch per request the
same way. Both `meta.json` descriptions declare it.

Correctness: `validate.sh orisha` **37/37** on the honest path; cleartext
and gzip bodies byte-identical to the memoized build's output (top-level
key order now `items,count` — matching the gzip path and zix's own
order; the validator parses semantically).

The price of honesty, measured on the local VM (generator-bound, so
direction-only): `/json/20?m=3` under `-p16 -c512` — memoized ~755-767K
rps, honest ~415-532K rps, roughly **−35%** on that endpoint. That is
what the cheat was worth, and it is what we paid to remove it. The
belief is bounded, not repudiated: serialize-the-invariant is still the
right pattern for a response cache a real app chooses to keep — it is
not the right move when the profile's measured work IS the
serialization, because then the memo table is the thing being benchmarked.

## What the instrument said — tenth pass (2026-10-11, the fused parse)

The eighth pass's open question is answered in code: `scanRequest` now
produces a `Head` — request line split (method/target), a capped array of
header name/value offsets, `head_len`, `chunked`, `wants_close` — in the
one walk it was already doing, and `answer` consumes it instead of
re-scanning. Offsets rather than slices, so the struct means the same
thing in any buffer; overflow past 64 headers stores `unstored_tail` and
misses resume as a line walk — lookup is exactly as complete as a scan.

The boundary changed with it: `answer` takes the `*Exchange` itself.
`pump:raw` copied every request into a per-request arena only because a
`->` return may not borrow a parameter (610_007) — taking `x` as a
parameter sidesteps the pin entirely, and the arena copy, `pump:fileno`,
and `pump:raw` calls all leave the arrived chain. Per request the head
block is now walked ONCE (was: up to eight passes counting the two
`rawHasHeaderName` byte probes, which also silently died).

Every lazy accessor follows: `Request.head` carries the parse, so
`req.header`, `cookie`, `ws-accept`, `form` consult pairs first and scan
only the overflow tail. `rawHasHeaderName` is deleted outright.

Mechanism confirmed by same-load perf (`-p16 -c512`, LinuxKit): front-end
userspace ~33% → ~13% of samples — `arrived`+`indexOfPos`+
`dispatchHttpSlice`+`headerValue` collapsed into `dispatchHttpSlice`
8.67% + `indexOfPos` 3.49% + `headValueParsed` 1.08%. Throughput still
unpriced locally (7.58–7.73M both builds, generator-bound as ever).

Correctness: 9/9 hand probes (fragmented head, same-write pipeline,
close+EOF, CL/chunked body + successor, dup CL, malformed CL→chunked,
gzip negotiation through the pair lookup, query-string target) plus the
overflow case — `Accept-Encoding` at header position 71 found through
`unstored_tail`, gzip negotiated, body decompresses to valid JSON.
HttpArena `validate.sh orisha`: **37/37 pass** on the fused code.

## What the instrument said — eleventh pass (2026-10-11, the send-path bake)

The same belief reached the head. A baked-route response is `head[0..hole] +
Date + head[hole..] + body` — four segments through `appendPending` per
request, three copies into `send_buf`. Everything but the Date is rodata,
and the Date flips once a second: the wire message is *invariant per
(second, head-ptr)*. `bakedSegment` composes it once into a 4-slot
direct-mapped threadlocal bake keyed on `head.ptr` + the line's bytes —
per request the send pays one ~150B copy instead of three splices. A
non-static or oversized head composes uncached or keeps the three-segment
path. The mechanism also removed the last lazy lookups: `scanRequest`
captures `accept-encoding`/`if-none-match` offsets inline (first-char +
length dispatch before `eqlIgnoreCase`), `answer` consumes them, and
`headValueParsed` leaves the hot profile entirely; `indexOfLineEnd` went
`inline` and `requestPathKey`'s second `?` scan folded into
`pathKeyDecoded`.

Profile under `-p16 -c800` (LinuxKit): `headValueParsed` gone (was ~6%),
`requestPathKey` 6.9% → `pathKeyDecoded` 2.2%. Throughput: **unpriced** —
gcannon at `-c800 -t8` is itself ~30% parse-bound and the VM swings ±30%
run to run; interleaved A/Bs read as noise. The mechanism claims are
profile-verified; the rps claim awaits a server-bound instrument.

## What the instrument said — twelfth pass (2026-10-11, the epoch check)

One level deeper, the same move: callee-graph perf put `time` +
`clock_gettime` at **5.1% of server CPU** inside `writevAllConn` — every
response read the wall clock to learn whether the Date second had flipped.
The header itself can only express seconds, so a per-request read measures
nothing it can print. `stampHttpDateLine` now runs once per event-loop
wakeup (all five pumps: kqueue ×2, epoll, io_uring, unikraft poll) and
`httpDateLine` returns the stamped line in one branch; a thread with no
tick keeps the refresh-per-call behavior it always had, so an unstamped
pump degrades to the old path rather than serving a frozen Date. The
29-byte `formatHttpDate` slice came along — it was a second per-response
`time()` on the composed-head path, now `line[6..35]`.

Post-change perf: `clock_gettime` absent, `writevAllConn` inclusive
27.3% → 14.8%. Interleaved A/B at `-c800 -t8 -p16` leaned +7% (3/4 pairs)
inside the VM noise — mechanism verified by profile, throughput still
unpriced.

## What the instrument said — thirteenth pass (2026-10-11, the wire itself)

Both servers' pipelined profiles are kernel-bound with nearly identical
shapes (~30% `io_send`/`tcp_sendmsg`), so the remaining zix gap was never
parse speed — it was **bytes moved per response**: ~121B versus ~63B on
the same 2-byte body. The audit of our head found the pure-noise line:
`Connection: keep-alive`, 25 bytes of redundancy under HTTP/1.1 (keep-alive
is the default; `wants_close` already keys only on `Connection: close`,
and no HTTP/1.0 path exists to change semantics). It is gone from all six
emission sites — baked literal, composed heads, hydration builder,
`response_304`. Wire per pipeline response: ~121B → ~102B; the residual
delta to zix's ~63B is our Date line and self-id headers — features we
keep deliberately, not oversights. Interleaved A/B `-c800 -t8 -p16`:
3/4 pairs to the slim build, mean ~11.33M vs ~11.20M — inside the VM's
noise band; priced verdict belongs to the server-bound droplet.

Priced on the droplet (same harness, `pipelined` profile, best-of-3):
1,865,282 → **1,941,378 req/s** (+4.1%) against zix's 2,456,538. The
remaining gap is not sends: perf-stat tracepoints under identical load
show zix submitting **more** SQEs per request (0.189 vs our 0.126) yet
moving 16% more requests — because their per-request CPU is ~0.58 µs
(2.46M @ 142% CPU) versus our ~1.04 µs (1.94M @ 202% CPU). Our userspace
self-time is ~27% of samples (dispatch blob ~17.6%, staging ~6%),
concentrated ~40% at the `writevAllConn` call edge and ~13% in the
AVX-512 request scan; zix's userspace is ~0%. The gap is per-request
machinery depth, not transport. A `date_hole` memo keyed on the static
body pointer was tried and **reverted**: −4.5% over 8 interleaved pairs —
the probe's added branch in the inlined blob cost more than two SIMD
scans it replaced (the `headValuesParsed2` lesson repeats).

The first structural answer to the machinery finding is the
request-free dispatch: `handler-lite`, an abstract tor the route
transform fills with exact-literal route arms that never mention `req`.
`answer` consults it before building `Request` — a static hit skips
Request construction, etag/accept-encoding extraction, and the handler
call entirely. Priced on a c-4 droplet, interleaved alternating-order
pairs, `-c4096 -t4 -p16` pipelined: **+2.0%** on the static route
(1,621,250 vs 1,588,750 mean, lite ahead 6/8 pairs), **−1.3%** on
`/baseline11` dynamic misses (140,596 vs 142,382, behind 4/5) — the
probe tax every request pays for a walk it didn't take. Validator
37/37 on the exact lite binary. The deeper form of the same cut — one
ordered match chain where literal arms return and dynamic arms carry
their match into Request construction — removes the double-match
instead of adding a probe.

## Open questions

- Whether the fused front-end buys throughput on a server-bound regime —
  ~20 points of userspace removed; the single-core-pinned droplet or the
  board is the instrument.
- Whether `std.json.Stringify` can be made fast enough to close the
  jzon gap — commissioned out for the emit path (chunked writes, escape
  table); the serializer is ~40% of /json CPU and is toolchain, not entry.
- Whether the terminal-CQE pass can do less (deferred-free batching) —
  the second half of the named surgery, not yet attempted; churn profiles
  need a stronger generator than a 4-vCPU box to price it.
- kTLS engagement — ANSWERED on the 2026-10-11 droplet race box
  (kernel 6.12.111+deb13-amd64): `ss -ti` showed `tcp-ulp-tls version:
  1.3 cipher: aes-gcm-256` on **513/513** established conns under `wrk
  -c512`, so engagement is universal under load, not a quiet-point fluke.
  That reframes the json-tls deficit: kTLS is live on every conn, and
  zix's binary carries no `TCP_ULP` strings at all — their edge is
  userspace-TLS path efficiency, not offload. Local engagement remains
  impossible (LinuxKit arm64, `CONFIG_TLS` unset); the droplet is the
  only honest instrument for TLS questions.
- The heap `Stringify` fallback for overflow counts is unchanged and
  unmeasured for speed — it only needs to be correct.
