# korulang.org, served by Orisha

Orisha speaks plain HTTP and has no HTTPS of its own. Everything here is the
shape that gap takes in production: Caddy holds the certificate and speaks TLS
to the world, Orisha serves the site behind it on a private network. That is
what sits in front of most servers on the internet.

Two containers. The site is compiled *into* the Orisha binary, so the image has
no libc, no shell and no site directory in it — `FROM scratch` and one file.

## Run it locally

```
cd ~/src/korulang_org && pnpm build:static
cd ~/src/orisha/examples/korulang-site && koruc main.kz --build=linux
HTTP_PORT=8880 HTTPS_PORT=8443 docker compose -f deploy/compose.yaml up -d --build
```

Then `https://localhost:8443`. The certificate comes from Caddy's own authority,
so curl needs told about it:

```
docker compose -f deploy/compose.yaml cp caddy:/data/caddy/pki/authorities/local/root.crt /tmp/caddy-root.crt
curl --cacert /tmp/caddy-root.crt https://localhost:8443/
```

**The local config never contacts a certificate authority.** This matters more
than it sounds. Caddy treats a real domain name in its config as an instruction
to go and fetch a real certificate for it, from a public authority, the moment
it starts — so a config file naming `korulang.org` is not a statement of intent,
it is an outward action with a trigger on it. `compose.yaml` therefore defaults
to `Caddyfile.local`, which names only `localhost` and signs locally. The TLS is
real; only the signature is.

## Go live

This part is not automated on purpose — it spends money, claims a domain, and
moves a live site off Vercel.

1. Put the two files and the binary on the host.
2. Point `korulang.org` and `www.korulang.org` at that host's address.
3. Set a real operator address in `Caddyfile` (the `email` line).
4. `CADDYFILE=./Caddyfile docker compose -f deploy/compose.yaml up -d --build`

Caddy obtains and renews the certificate by itself, on the strength of the DNS
records resolving to that machine. There is no certificate step to run and
nothing to remember to renew. Step 2 is the one that cannot be undone quickly:
until DNS propagates back, the site is wherever you pointed it.

**Publishing a post means recompiling.** The site is embedded at compile time,
so a content change is a rebuild and a redeploy, not a file sync.

## What has actually been verified

On this stack, locally, against the real 1119-file site build: every file
byte-identical over HTTPS on one connection, a TLS 1.3 handshake
(`TLS_AES_128_GCM_SHA256`, X25519MLKEM768 key exchange), HTTP/2 negotiated, and
plain HTTP answered with a 308 to HTTPS. The Orisha binary under test was the
x86_64 Linux one — the same artifact a server would run.

Nothing here has been deployed anywhere, and no public certificate has been
issued.
