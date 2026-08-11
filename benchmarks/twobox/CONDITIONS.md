# Conditions

Everything needed to disbelieve these numbers, or reproduce them for about a
dollar. If something you need to check the result is missing from this file,
that is a bug in the file.

## Hardware, and why it was rented rather than borrowed

Two DigitalOcean `c-4` droplets — 4 dedicated vCPU, 8 GB — in `ams3`, on one
private network. One serves, one generates load, and they are never the same
machine.

That separation is the reason this directory exists. Every Orisha number
published before 2026-08-11 was taken with the load generator on the same
machine as the server, competing with it for the same cores. Those numbers are
fine as ratios and worth nothing as throughput.

**Dedicated CPU, not shared.** A shared-tenancy instance loses cycles to its
neighbours and does not mention it. Steal is sampled from `/proc/stat` around
every run and printed anyway — it has come in around 0.2%.

**The CPU model is recorded per run and is not stable.** The same droplet size in
the same region has returned a Xeon Platinum 8280 on one run and an 8168 on the
next. Two runs are not comparable without checking it.

## What is served

korulang.org's real static build — 1,118 files, roughly 66 MB uncompressed.
Not synthetic fixtures.

## The rules, and the measurement that produced each one

Every one of these exists because something lied to us first.

**Files are baked into images, never bind-mounted.** A bind mount on macOS once
made Orisha look 7× faster than nginx. It was measuring the host filesystem
bridge.

**Every response is byte-compared against the original before anything is
timed**, and a contestant that fails is not timed at all. A fast server returning
wrong bytes scores nothing. This caught OpenLiteSpeed serving its own 404 page to
all 1,118 requests at a perfectly respectable speed.

**Compression parity is read off the wire per contestant.** Orisha compresses at
compile time; every other contestant is given the same precompressed files and
configured to serve them. Verified from the response headers, never from the
config file — config says what was intended.

**Worker counts are equal and stated.** Comparing one worker against twelve
produced a completely believable and completely wrong result earlier the same
day.

**Contestants are interleaved** (a, b, c, d, a, b, c, d) so a busy moment lands
on everyone rather than on whoever was running during it, and the report takes
the **median** of rounds rather than the best, because a best-of hides the
variance that says whether a number means anything.

**A contestant whose image will not build is named in the report as excluded,
with the reason.** A missing contestant looks exactly like one that lost.

**Sandbox settings are identical for everyone.** `seccomp=unconfined` is applied
to every container, not only to ours — Docker's default profile blocks
`io_uring_setup`, and a blocked syscall is indistinguishable from a missing
feature from the inside.

## Known ceilings

**The network caps any payload above a few KB.** On the 13 KB page, four
unrelated servers landed within 0.6% of each other — 18,163 to 18,268 req/s.
13,340 bytes × 18,200/s is about 1.94 Gbit/s, which is the link. That column
measures the cable and is reported as a ceiling, not a ranking.

**One hot URL is not a site.** Throughput on a single file says little about
serving 1,118 of them. The profile experiment uses a Zipf-skewed spread across
the whole site for that reason.

## Contestants

| server | how it is built | notes |
|---|---|---|
| Orisha | compiled here, x86_64-linux-musl, site inside the binary | `FROM scratch`, one file |
| nginx | `nginx:stable` | `sendfile`, `tcp_nodelay`, `tcp_nopush`, `open_file_cache`, `gzip_static` |
| H2O | Debian package | `file.send-compressed: ON` |
| Caddy | `caddy:2-alpine` | `file_server` with `precompressed gzip` |
| static-web-server | `joseluisq/static-web-server:2` | Rust; `SERVER_COMPRESSION_STATIC` |
| OpenLiteSpeed | `litespeedtech/openlitespeed` | its Example vhost's `/docs/` context is removed, having shadowed the site's own `/docs/` |

Full configuration for every one is in `server/setup.sh` — not summarised here,
because a summary of a config is a place for a discrepancy to hide.

## Reproducing

Needs `doctl` authenticated and an SSH key named `koru-bench` on the account.

    ./run.sh                  # the matrix
    ./profile-experiment.sh   # profiled vs unprofiled, nginx and H2O as controls
    ./teardown.sh             # destroy whatever is left

Roughly $0.25/hour for the pair, destroyed at the end of a run.

## What these numbers are not

Static files over HTTP/1.1 with keep-alive, one machine size, one datacenter, one
site. Nothing here says anything about TLS, dynamic content, or behaviour under a
real traffic mix.

## The profile experiment: inconclusive, and why that is the honest word

Compiling the site against a held-out sample of its own traffic gave a median
2.8% over the unprofiled build (155,075 against 150,900 req/s). It is tempting to
report that as a small win. It is not one.

    orisha-cold   150,900   154,557   147,244     (5% spread, same binary)
    orisha-warm   147,356   155,075   160,379     (9% spread, same binary)

Cold led round one. Warm led rounds two and three. The difference *between* the
builds is smaller than the difference between a build and itself, and three
rounds cannot resolve that. The result is neither "layout helps" nor "layout does
nothing" — it is "this rig cannot tell", which is a different claim and the only
one the data supports.

The controls are what make even that statement possible: nginx held a 2.4% spread
across the same three rounds on a server nothing in the experiment could touch.
That is the measured noise floor, and any effect smaller than it is invisible
here by construction.

**What would settle it.** More rounds, and a machine where residency is not free.
A 23 MB binary on 8 GB is entirely resident within seconds, and where a response
*sits* stops mattering when nothing has to be fetched. Layout pays under memory
pressure; this experiment had none.

## Results

`results/<timestamp>/` holds the report, the raw per-round lines, and the machine
provenance for every run — including the runs where most contestants were
excluded by our own misconfiguration, which are kept rather than deleted.
