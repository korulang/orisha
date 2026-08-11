# Two-box benchmark — 2026-08-11T14-19-53Z

```
region=ams3 size=c-4 image=debian-13-x64
server=6.12.94+deb13-amd64 4  Intel(R) Xeon(R) Platinum 8168 CPU @ 2.70GHz 
load=6.12.94+deb13-amd64 4 
duration=15s rounds=3 workload=/index.html@200 /index.html@50 /200.html@200
--- excluded contestants ---
```

## Throughput (median of rounds, requests/sec)


**`/200.html` at 200 connections**

| server | req/s | p50 | p99 | non-2xx |
|---|---|---|---|---|
| orisha-epoll | 159,381 | 0.87ms | 6.32ms | 0 |
| h2o | 142,654 | 1.22ms | 5.95ms | 0 |
| nginx | 121,399 | 1.76ms | 7.44ms | 0 |
| orisha-uring | 68,505 | 3.26ms | 3.48ms | 0 |
| sws | 52,278 | 3.78ms | 7.34ms | 0 |
| caddy | 20,437 | 8.94ms | 39.40ms | 0 |

**`/index.html` at 200 connections**

| server | req/s | p50 | p99 | non-2xx |
|---|---|---|---|---|
| orisha-epoll | 18,268 | 7.69ms | 525.30ms | 0 |
| orisha-uring | 18,247 | 7.88ms | 474.64ms | 0 |
| caddy | 18,194 | 8.12ms | 596.76ms | 0 |
| nginx | 18,163 | 7.59ms | 603.32ms | 0 |
| h2o | 18,118 | 7.64ms | 541.79ms | 0 |
| sws | 18,049 | 7.56ms | 569.39ms | 0 |

**`/index.html` at 50 connections**

| server | req/s | p50 | p99 | non-2xx |
|---|---|---|---|---|
| orisha-uring | 18,309 | 815.00us | 246.19ms | 0 |
| orisha-epoll | 18,301 | 1.12ms | 214.44ms | 0 |
| caddy | 18,171 | 2.02ms | 209.76ms | 0 |
| nginx | 18,167 | 0.92ms | 274.47ms | 0 |
| h2o | 18,161 | 0.93ms | 215.44ms | 0 |
| sws | 18,131 | 0.93ms | 238.97ms | 0 |

## Correctness — checked before anything was timed

| server | identical | wrong | of |
|---|---|---|---|
| caddy | 1118 | 0 | 1118 |
| h2o | 1118 | 0 | 1118 |
| nginx | 1118 | 0 | 1118 |
| ols | 1111 | 7 | 1118 |
| orisha-epoll | 1118 | 0 | 1118 |
| orisha-uring | 1118 | 0 | 1118 |
| sws | 1118 | 0 | 1118 |

## CPU steal on the server during runs

Steal is cycles the hypervisor gave to someone else. Reported as a share
of the run so it can be judged rather than just noted: under ~1% is
ordinary even on dedicated instances, and several percent means the
number above is not about the server.

| server | steal ticks (per round) |
|---|---|
| caddy | 1, 1, 2 |
| h2o | 20, 12, 14 |
| nginx | 8, 14, 27 |
| orisha-epoll | 7, 14, 25 |
| orisha-uring | 5, 3, 3 |
| sws | 22, 39, 32 |
