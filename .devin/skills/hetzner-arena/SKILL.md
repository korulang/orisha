# hetzner-arena — commission, race, and ALWAYS delete

Hetzner cloud boxes for Orisha/Koru benchmark races. Boxes are **per-run**:
commission, measure, sweep artifacts, **delete**. A box left running is a money
leak — the run is not done until the server is gone.

## Credentials

- API token: `HCLOUD_TOKEN` env (ask Lars — do not store the token in the repo).
- SSH key: `~/.ssh/koru_bench` (registered in the project as `koru-bench`).
- API: `https://api.hetzner.cloud/v1` with `Authorization: Bearer $HCLOUD_TOKEN`.

## Find what's running (always first)

```bash
curl -s -H "Authorization: Bearer $HCLOUD_TOKEN" \
  https://api.hetzner.cloud/v1/servers
```

Any `running` server not commissioned by the current session is a leak —
report it and delete it unless Lars says keep it.

## Commission

```bash
curl -s -X POST -H "Authorization: Bearer $HCLOUD_TOKEN" \
  -H "Content-Type: application/json" \
  https://api.hetzner.cloud/v1/servers -d '{
    "name": "arena-bench",
    "server_type": "cax41",          # arm64 16 vCPU; ccx* for x86/dedicated
    "image": "ubuntu-24.04",
    "location": "fsn1",
    "ssh_keys": ["koru-bench"]
  }'
```

x86 (`ccx*`) is required for amd64-faithful numbers (TFB hardware). arm64
(`cax*`) matches Apple-silicon local dev and is cheaper.

Wait for `status: running`, grab `public_net.ipv4.ip`, then:

```bash
ssh -i ~/.ssh/koru_bench -o StrictHostKeyChecking=accept-new root@<ip>
```

## Push images (no registry needed)

```bash
docker save <image> | ssh -i ~/.ssh/koru_bench root@<ip> "docker load"
```

## Race topology (16 cores, --network host)

- server: `--cpuset-cpus=0-7 --privileged` (io_uring needs privs)
- postgres: `--cpuset-cpus=12-15`, `postgres:16-alpine`,
  `POSTGRES_USER=benchmarkdbuser POSTGRES_PASSWORD=benchmarkdbpass
   POSTGRES_DB=hello_world`, seed via `create-postgres.sql`
  (TFB canonical: `toolset/databases/postgres/create-postgres.sql`)
- gcannon: `--cpuset-cpus=8-15 --privileged`
- server env for db routes: `PG_HOST=127.0.0.1 PG_USER=benchmarkdbuser
  PG_PASS=benchmarkdbpass PG_DB=hello_world`

Throughput shapes (learned the hard way):
- `-c 256` serial conns is conn-latency-bound (~300K req/s ceiling) — it
  measures latency, not pump capacity.
- Real throughput needs `-c 4096 -t 64 -d 5s -p 16` (pipelined).
- `/db` oracle: `pgbench -c 64 -j 8 -f <pk-select.sql>` gives postgres's own
  ceiling — never report app q/s without it, or you'll name postgres's wall
  as ours.
- Interleave A/B runs (orisha, uws, orisha, uws) — single runs are noise.

## Sweep + delete (mandatory, same session)

Numbers live in the transcript; nothing on the box needs pulling unless the
user asks for artifacts. Then:

```bash
curl -s -X DELETE -H "Authorization: Bearer $HCLOUD_TOKEN" \
  https://api.hetzner.cloud/v1/servers/<id>
```

Verify with the servers list call. Report the delete action id and the
approximate spend (server_type hourly price × uptime). **The task is not
complete until the list is empty.**
