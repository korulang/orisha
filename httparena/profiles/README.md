# HttpArena profile mixes for `orisha.profile`

Generated logs live in `generated/` (gitignored). Checked-in reference mixes can be added here when pinned for board runs.

| Mix name | HttpArena profile | Paths emulated |
|----------|-------------------|----------------|
| `baseline` | baseline | `/baseline11` (GET+POST rotation in gcannon) |
| `limited-conn` | limited-conn | `/baseline11` |
| `pipelined` | pipelined | `/pipeline` |
| `json-comp` | json-comp | `/json/25`, `/json/40`, `/json/50` |
| `json-tls` | json-tls | same json paths (TLS is transport) |
| `latency` | latency-1m, latency-10k | `/baseline11` (fixed GET in zrk) |
| `board-mix` | composite prep | weighted mix of all orisha routes |

Generate:

```bash
./workload.py --profile baseline --train profiles/generated/baseline.profile
./build.sh warm baseline
```

See [`PGO.md`](../PGO.md) for the full compile-time PGO story.
