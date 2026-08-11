# Two-box benchmark — 2026-08-11T14-54-58Z

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
| orisha-epoll | 202,678 | 537.00us | 112.65ms | 0 |
| h2o | 133,649 | 1.43ms | 4.06ms | 0 |
| nginx | 118,761 | 1.54ms | 2.66ms | 0 |
| orisha-uring | 105,633 | 1.82ms | 2.45ms | 0 |
| ols | 97,184 | 1.79ms | 5.34ms | 0 |
| sws | 51,243 | 3.89ms | 7.32ms | 0 |
| caddy | 20,107 | 9.13ms | 37.42ms | 0 |

**`/index.html` at 200 connections**

| server | req/s | p50 | p99 | non-2xx |
|---|---|---|---|---|
| orisha-epoll | 18,300 | 7.87ms | 411.69ms | 0 |
| orisha-uring | 18,278 | 7.93ms | 415.96ms | 0 |
| caddy | 18,223 | 7.90ms | 609.02ms | 0 |
| nginx | 18,183 | 7.78ms | 576.17ms | 0 |
| h2o | 18,169 | 7.87ms | 422.60ms | 0 |
| sws | 18,131 | 7.70ms | 427.46ms | 0 |
| ols | 18,119 | 7.99ms | 535.37ms | 0 |

**`/index.html` at 50 connections**

| server | req/s | p50 | p99 | non-2xx |
|---|---|---|---|---|
| orisha-uring | 18,346 | 500.00us | 209.07ms | 0 |
| orisha-epoll | 18,336 | 590.00us | 207.85ms | 0 |
| h2o | 18,206 | 531.00us | 207.79ms | 0 |
| nginx | 18,182 | 555.00us | 211.84ms | 0 |
| sws | 18,178 | 635.00us | 209.02ms | 0 |
| caddy | 18,176 | 2.00ms | 215.85ms | 0 |
| ols | 18,098 | 757.00us | 208.91ms | 0 |

## Correctness — checked before anything was timed

| server | identical | wrong | of |
|---|---|---|---|
| caddy | 1118 | 0 | 1118 |
| h2o | 1118 | 0 | 1118 |
| nginx | 1118 | 0 | 1118 |
| ols | 1118 | 0 | 1118 |
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
| caddy | 7, 7, 8 |
| h2o | 21, 11, 13 |
| nginx | 13, 11, 14 |
| ols | 10, 7, 11 |
| orisha-epoll | 15, 12, 20 |
| orisha-uring | 3, 5, 5 |
| sws | 21, 14, 13 |
