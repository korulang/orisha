---
cost: tls-sockbio-userspace-tax
organ: io_uring pump TLS path (lib/pump.kz) + koru-libs/openssl ctx setup
status: closed
measured-on: hunt-b, linuxkit 6.12.76 aarch64 Docker VM (no CONFIG_TLS —
  the userspace socket-BIO path is what this instrument exercises)
---

# the socket-BIO userspace tax: one staging copy + two dead read()s per request

**Cost.** On a conn that stays on userspace crypto (kTLS refused or
absent), every response paid:

1. A full-body memcpy the plaintext pump never pays — `ringRenderTarget`
   refused TLS conns (`st.ssl != null` → null), so `jsonResponse` rendered
   into `body_work` scratch and `appendPair`/`appendPending` copied the
   whole message into `st.pending` before `SSL_write` copied it again into
   the record buffer. At `/json/50` that is ~8.5 KB of pure waste per
   request.
2. Two `read()` syscalls per request that can only EAGAIN —
   `sockbioRead` looped `SSL_read` until WANT_READ (one dead read per
   poll CQE) and OpenSSL's default record walk does a second short read
   per fragment. strace under load: `read` : `write` = **3.0 : 1**
   (213,368 / 71,120).

**Fix.**
- `pump.kz` — `ringRenderTarget` now hands a socket-BIO TLS conn the
  `pending` tail (that buffer is the conn's own pre-encryption queue;
  `send_buf` stays ciphertext-only). `pendingClaim` claims the rendered
  span by pointer: contiguous tail → `items.len` extension, head-parked
  render on an empty queue → `pending_off` skip of the HEAD_RESERVE gap.
  Renderers only get the tail when the queue is fully drained, so every
  rendered span is claimable and a mid-queue gap can never form.
- `pump.kz` — `sockbioRead` retries `SSL_read` only while
  `SSL_has_pending` reports buffered record data; a bare retry buys one
  guaranteed-EAGAIN `read()`. Ciphertext still in the kernel re-fires the
  re-armed POLLIN.
- `koru-libs/openssl/index.kz` — `SSL_CTX_set_read_ahead(ctx, 1)` on the
  server ctx: one socket read pulls every record the kernel has, instead
  of header/body fragments. Also `SSL_OP_CIPHER_SERVER_PREFERENCE` +
  ciphersuites preferring `TLS_AES_128_GCM_SHA256` — the TLS 1.3
  mandatory cipher, ~15% cheaper per byte than AES-256-GCM on hardware
  AES (wrk/s_client negotiate client-preference otherwise, so the server
  order never applied). Verified negotiated: `Cipher is
  TLS_AES_128_GCM_SHA256` (was `TLS_AES_256_GCM_SHA384`).

**Measurement** — wrk `-t 6 -c 512 -d 8s https://…/json/50?m=2`,
interleaved A/B same ports, noisy box (sibling hunts live — best
per arm is the estimator):

- TLS, two independent interleaved sessions:
  - before (9530fed): max 250,780 rps → after: max 266,409 rps
    (**+6.2%**, 5/6 within-round wins)
  - before: max 259,924 rps → after: max 271,631 rps
    (**+4.5%**, 4/6 within-round wins)
- plaintext arm parity: before max 400,252 → after max 408,411 (noise;
  the cleartext path is untouched).
- strace after: `read` : `write` = **1 : 1** (100,565 / 100,567) — the
  two dead reads are gone; the pending copy is gone (render claims the
  queue span).
- `validate.sh orisha` on the final image: **37 passed, 0 failed**
  (json-tls probes negotiate TLS 1.3 / AES_128_GCM and match dataset
  items). `validate-frag.py` 9/9; TLS probe (keepalive, rapid, true
  pipeline, split writes, conn close, gzip, 48 concurrent, POST)
  identical pass/fail profile before and after.

**Board caveat (honest).** The VM kernel has `CONFIG_TLS=n`, so this
instrument can only see the userspace path. If `SSL_OP_ENABLE_KTLS`
actually engages on the board (verified only on linuxkit in 4f6e8e4 —
unproven on a TLS-capable kernel), offloaded conns run cleartext-shaped
and this diff does not touch the −18% board gap; that gap would then be
kernel-side AEAD/framing, unreachable from this box. What is closed here
is the fallback path every conn pays when offload is absent or refused —
which, on the board, is either the measured cost or dead code.

**Probe discipline note:** an earlier version of this entry claimed a
pre-existing pipelined-TLS stall on both arms — that was a bug in the
probe's own response reader (unbuffered `recv` discarded the second
response's leading bytes). With a correct buffered reader both arms pass
keepalive, rapid back-to-back, true pipelining, split writes, close,
gzip, 48-concurrent and TLS POST identically.
