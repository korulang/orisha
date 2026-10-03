# Two-box benchmark — 2026-10-03T07-20-22Z (aborted in verify)

Run killed during the correctness phase, before any timing existed. Kept
because it is the failure that found the io_uring double-close.

```
region=fra1 size=c-4 image=debian-13-x64
```

**orisha-uring failed correctness 0/6163.** The server answered one request
and then panicked: `releaseConn(fd)` already closes the descriptor, and every
teardown path in the io_uring drive called `posix.close(fd)` a second time —
EBADF, `unreachable` in `std.posix.close`, worker dead on the first closed
connection. Pre-existing in the uring path; invisible until now because no
run had exercised connection teardown on this pump since it landed.

Fixed in `lib/pump.kz` (the four `releaseConn; posix.close` pairs lost the
second close) and verified on the server box itself — five sequential
requests, zero panics — before the matrix was re-run as
`2026-10-03T08-04-24Z`.

Also recorded by this run: orisha's baked gzip is 13,383 bytes on the wire
against 13,355 for the precompressed siblings — the same small delta the
August runs carried (13,339 vs 13,312), on a site that has since grown to
6,163 files.
