---
type: belief
id: frag-ktls-is-a-quiet-point-handoff
provenance: io_uring pump TLS offload, 2026-10 — verified on Linux 6.12 (TlsTxSw/TlsRxSw live, post-install requests served)
ts: 2026-10-07
---

# kTLS offload is a quiet-point handoff, not a socket mode (belief)

The pump's TLS path runs memory BIOs end to end and, exactly once per
connection, hands the finished session to the kernel's record layer. The
handoff is safe only at a provable seam: no send SQE in flight, no staged or
pending output, no partial record in `tls_in`, nothing inside rbio or SSL
unread, handshake complete, no peer KeyUpdate in flight. There — and only
there — the kernel can continue the AEAD stream from the counted record
sequence numbers without a byte being owned by two layers.

## The shape that fell out

- Record sequence numbers are counted, not asked for: `ktls_rx_seq` counts
  post-handshake records fed to rbio, `ktls_tx_seq` counts records that left
  wbio for the wire. OpenSSL will not tell you either.
- After install the conn is *literally* a cleartext ring conn — `st.ssl` is
  null, recv SQEs take plaintext into `st.buf`, sends are plaintext the
  kernel seals. There is no "TLS mode" left to maintain.
- `.unsupported` parks the conn on memory BIOs forever — ULP attach alone
  is byte-identical on the wire, so a refused install costs nothing.
- Teardown of an offloaded conn is `TLS_SET_RECORD_TYPE` via cmsg — the
  kernel wraps close_notify under its own keys; userspace cannot spell it.

## What it is not

Not faster by itself. On the json-tls profile (small bodies, high churn)
offload measured parity with the memory-BIO path — ~35K req/s vs ~39K on the
earlier no-offload build, inside noise. The payoff is structural: SSL object
freed per conn, crypto moved to the kernel, `sendfile` on TLS becomes
reachable. The benchmark delta has to come from the ring, not the cipher.

## Open questions

- Half-install (RX ok, TX refused) is `.fatal` by construction — the conn
  would otherwise carry two record layers. Unprobed on a real kernel.
- `TlsDecryptError` accounting for sequence drift under pipelined bursts is
  verified at 0 only for the tested patterns.
