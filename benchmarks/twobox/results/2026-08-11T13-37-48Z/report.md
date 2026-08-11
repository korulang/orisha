# Two-box benchmark — 2026-08-11T13-37-48Z

```
region=ams3 size=c-4 image=debian-13-x64
server=6.12.94+deb13-amd64 4  Intel(R) Xeon(R) Platinum 8280 CPU @ 2.70GHz 
load=6.12.94+deb13-amd64 4 
duration=15s rounds=3 workload=/index.html@200 /index.html@50 /200.html@200
--- excluded contestants ---
```

## Throughput (median of rounds, requests/sec)


**`/200.html` at 200 connections**

| server | req/s | p50 | p99 | non-2xx |
|---|---|---|---|---|
| orisha-epoll | 171,818 | 769.00us | 6.15ms | 0 |
| caddy | 24,167 | 7.72ms | 34.53ms | 0 |

**`/index.html` at 200 connections**

| server | req/s | p50 | p99 | non-2xx |
|---|---|---|---|---|
| orisha-epoll | 18,274 | 7.66ms | 589.27ms | 0 |
| caddy | 18,164 | 6.57ms | 586.83ms | 0 |

**`/index.html` at 50 connections**

| server | req/s | p50 | p99 | non-2xx |
|---|---|---|---|---|
| orisha-epoll | 18,311 | 797.00us | 256.00ms | 0 |
| caddy | 18,150 | 1.47ms | 214.79ms | 0 |

## Correctness — checked before anything was timed

| server | identical | wrong | of |
|---|---|---|---|
| caddy | 1123 | 0 | 1123 |
| h2o | 0 | 1123 | 1123 |
| nginx | 1122 | 1 | 1123 |
| ols | 0 | 1123 | 1123 |
| orisha-epoll | 1123 | 0 | 1123 |
| orisha-uring | 0 | 1123 | 1123 |
| sws | 1118 | 5 | 1123 |

## CPU steal on the server during runs

Non-zero steal means the machine lost cycles to a neighbour and the run
is suspect, however good the number looks.

| server | steal ticks (per round) |
|---|---|
| caddy | 25, 24, 39 |
| orisha-epoll | 41, 47, 48 |
