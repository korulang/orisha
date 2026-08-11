# The two-box benchmark

Every number Orisha has published until now was measured with the load generator
running on the same machine as the server, competing with it for the same cores.
That is fine for a ratio and not fine for anything else, and it is the single
largest thing wrong with our previous benchmarks.

This runs the servers on one machine and the load on another, over a private
network, on rented hardware anyone can rent for about a dollar.

## What makes it honest

Each of these exists because a specific measurement lied to us first.

- **Two machines.** The load generator never competes with the server for a
  core. This is the whole point.
- **Dedicated CPU, and steal is recorded.** Shared-tenancy machines lose cycles
  to neighbours invisibly. We rent dedicated ones, sample `steal` from
  `/proc/stat` throughout every run, and print it. **Any run with non-zero steal
  is reported as suspect rather than quietly averaged in.**
- **One contestant runs at a time.** No cross-interference, and the box is
  checked idle between runs.
- **Every response is byte-compared against the original before anything is
  timed.** A fast server that returns the wrong bytes scores zero, not a high
  number. Ours once returned a 1.5 MB image at five different sizes on five
  consecutive requests while looking perfectly healthy.
- **Identical bytes on the wire.** Orisha compresses at compile time, so every
  other contestant is given the same precompressed files and told to serve them.
  Checked on the wire per contestant, not assumed from config.
- **Files are baked into images, never bind-mounted.** A bind mount once made
  Orisha look 7x faster than nginx. It was measuring the filesystem bridge.
- **Interleaved rounds.** Contestants run a, b, c, d, a, b, c, d — so a busy
  moment lands on everyone rather than on whoever was running during it.
- **Everything is recorded**: kernel, droplet size, every contestant's version
  and full config, and the exact command line.

## What it does not claim

It measures static file serving over HTTP/1.1 with keep-alive, on one machine
size, in one datacenter. It is not a claim about TLS, about dynamic content, or
about how any of these behave under a real traffic mix.

## Running it

Needs `doctl` authenticated and an SSH key named `koru-bench` on the account.

    ./run.sh

Provisions two dedicated-CPU droplets in one region and VPC, ships the
artifacts, verifies correctness, runs the matrix, writes a report, and destroys
the droplets. Roughly $0.25/hour for the pair while it runs.

    ./run.sh --keep      # leave the droplets up for poking at
    ./teardown.sh        # destroy whatever is left
