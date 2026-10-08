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

## Open questions

- Multishot recv's throughput effect is unmeasured — the per-CQE re-arm
  is gone by construction; the droplet A/B still owes the number.
- The heap `Stringify` fallback for overflow counts is unchanged and
  unmeasured for speed — it only needs to be correct.
