# Two-box benchmark — 2026-08-11T13-58-36Z

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
| orisha-epoll | 162,040 | 0.93ms | 5.31ms | 0 |
| orisha-uring | 66,053 | 3.26ms | 3.44ms | 0 |
| sws | 51,852 | 3.76ms | 7.33ms | 0 |
| caddy | 20,612 | 9.03ms | 38.30ms | 0 |

**`/index.html` at 200 connections**

| server | req/s | p50 | p99 | non-2xx |
|---|---|---|---|---|
| orisha-epoll | 18,344 | 7.95ms | 396.85ms | 0 |
| orisha-uring | 18,335 | 7.89ms | 383.37ms | 0 |
| caddy | 18,224 | 7.23ms | 628.22ms | 0 |
| sws | 18,187 | 7.83ms | 423.08ms | 0 |

**`/index.html` at 50 connections**

| server | req/s | p50 | p99 | non-2xx |
|---|---|---|---|---|
| orisha-uring | 18,321 | 697.00us | 210.29ms | 0 |
| orisha-epoll | 18,315 | 700.00us | 211.31ms | 0 |
| sws | 18,161 | 753.00us | 215.15ms | 0 |
| caddy | 18,157 | 1.90ms | 211.20ms | 0 |

## Correctness — checked before anything was timed

| server | identical | wrong | of |
|---|---|---|---|
| caddy | 1117 | 0 | 1117 |
| h2o | 1116 | 1 | 1117 |
| nginx | 1116 | 1 | 1117 |
| ols | 1109 | 8 | 1117 |
| orisha-epoll | 1117 | 0 | 1117 |
| orisha-uring | 1117 | 0 | 1117 |
| sws | 1117 | 0 | 1117 |

## CPU steal on the server during runs

Steal is cycles the hypervisor gave to someone else. Reported as a share
of the run so it can be judged rather than just noted: under ~1% is
ordinary even on dedicated instances, and several percent means the
number above is not about the server.

| server | steal ticks (per round) |
|---|---|
| caddy | 2, 3, 1 |
| orisha-epoll | 12, 6, 4 |
| orisha-uring | 1, 4, 4 |
| sws | 15, 43, 29 |
