# Two-box benchmark — 2026-10-03T08-04-24Z

```
region=fra1 size=c-4 image=debian-13-x64
server=6.12.94+deb13-amd64 4  Intel(R) Xeon(R) Platinum 8168 CPU @ 2.70GHz 
load=6.12.94+deb13-amd64 4 
duration=15s rounds=3 workload=/index.html@200 /index.html@50 /200.html@200
--- excluded contestants ---
```

## Throughput (median of rounds, requests/sec)


**`/200.html` at 200 connections**

| server | req/s | p50 | p99 | non-2xx |
|---|---|---|---|---|
| h2o | 134,526 | 1.31ms | 3.35ms | 0 |
| nginx | 115,881 | 1.70ms | 2.44ms | 0 |
| ols | 93,109 | 1.83ms | 6.40ms | 0 |
| sws | 50,515 | 3.91ms | 7.61ms | 0 |
| orisha-epoll | 32,874 | 5.95ms | 11.90ms | 0 |
| caddy | 14,583 | 12.43ms | 62.24ms | 0 |
| orisha-uring | 12,392 | 14.61ms | 549.11ms | 0 |

**`/index.html` at 200 connections**

| server | req/s | p50 | p99 | non-2xx |
|---|---|---|---|---|
| nginx | 16,957 | 7.99ms | 583.28ms | 0 |
| sws | 16,939 | 7.77ms | 575.14ms | 0 |
| h2o | 16,920 | 8.03ms | 577.47ms | 0 |
| ols | 15,397 | 8.31ms | 509.90ms | 0 |
| caddy | 13,376 | 13.40ms | 75.34ms | 0 |
| orisha-uring | 11,895 | 15.77ms | 687.85ms | 0 |
| orisha-epoll | 11,559 | 9.61ms | 583.04ms | 0 |

**`/index.html` at 50 connections**

| server | req/s | p50 | p99 | non-2xx |
|---|---|---|---|---|
| h2o | 16,691 | 741.00us | 215.84ms | 0 |
| sws | 16,690 | 0.91ms | 207.63ms | 0 |
| nginx | 16,687 | 809.00us | 209.23ms | 0 |
| orisha-epoll | 15,540 | 1.79ms | 218.60ms | 0 |
| ols | 15,174 | 0.98ms | 206.54ms | 0 |
| caddy | 13,943 | 3.18ms | 15.12ms | 0 |
| orisha-uring | 10,889 | 5.07ms | 5.43ms | 0 |

## Correctness — checked before anything was timed

| server | identical | wrong | of |
|---|---|---|---|
| caddy | 6163 | 0 | 6163 |
| h2o | 6163 | 0 | 6163 |
| nginx | 6163 | 0 | 6163 |
| ols | 6163 | 0 | 6163 |
| orisha-epoll | 6163 | 0 | 6163 |
| orisha-uring | 6163 | 0 | 6163 |
| sws | 6163 | 0 | 6163 |

## CPU steal on the server during runs

Steal is cycles the hypervisor gave to someone else. Reported as a share
of the run so it can be judged rather than just noted: under ~1% is
ordinary even on dedicated instances, and several percent means the
number above is not about the server.

| server | steal ticks (per round) |
|---|---|
| caddy | 4, 13, 5 |
| h2o | 14, 15, 13 |
| nginx | 13, 16, 13 |
| ols | 12, 14, 16 |
| orisha-epoll | 10, 10, 11 |
| orisha-uring | 0, 1, 0 |
| sws | 14, 13, 14 |
