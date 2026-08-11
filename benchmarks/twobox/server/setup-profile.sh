#!/usr/bin/env bash
# Runs ON the server droplet. Builds every contestant with the site baked into
# its image.
#
# Baked in, never bind-mounted: a bind mount once made Orisha look 7x faster than
# nginx, because it was measuring the host filesystem bridge rather than either
# server. An image layer is the same storage for everyone.
set -euo pipefail
cd /root/bench

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq docker.io curl >/dev/null
systemctl enable --now docker >/dev/null 2>&1 || true

tar xzf site.tar.gz          # -> ./site  (with .gz siblings already generated)
chmod +x orisha-cold orisha-warm

mkdir -p build && cd build
cp -r ../site site
cp ../orisha-cold ../orisha-warm .

# --- Orisha -----------------------------------------------------------------
# The site is already inside these binaries; the image is one file and nothing
# else, which is what `FROM scratch` means here rather than a flourish.
for v in cold warm; do
	cat > Dockerfile.orisha-$v <<EOF
FROM scratch
COPY orisha-$v /server
ENTRYPOINT ["/server"]
EOF
done

# --- nginx ------------------------------------------------------------------
cat > nginx.conf <<'EOF'
worker_processes auto;
error_log /dev/null;
events { worker_connections 8192; use epoll; multi_accept on; }
http {
  include /etc/nginx/mime.types;
  access_log off;
  sendfile on; tcp_nodelay on; tcp_nopush on;
  open_file_cache max=4000 inactive=60s;
  open_file_cache_valid 60s;
  open_file_cache_min_uses 1;
  open_file_cache_errors on;
  gzip_static on;          # parity: serve the same precompressed bytes Orisha does
  keepalive_timeout 65; keepalive_requests 100000;
  server { listen 3000; root /srv; index index.html; }
}
EOF
cat > Dockerfile.nginx <<'EOF'
FROM nginx:stable
COPY nginx.conf /etc/nginx/nginx.conf
COPY site /srv
EOF

# --- Caddy ------------------------------------------------------------------
cat > Caddyfile <<'EOF'
{
	auto_https off
	admin off
}
:3000 {
	root * /srv
	file_server {
		precompressed gzip
	}
}
EOF
cat > Dockerfile.caddy <<'EOF'
FROM caddy:2-alpine
COPY Caddyfile /etc/caddy/Caddyfile
COPY site /srv
EOF

# --- static-web-server (Rust) ----------------------------------------------
cat > Dockerfile.sws <<'EOF'
FROM joseluisq/static-web-server:2
COPY site /srv
ENV SERVER_ROOT=/srv SERVER_PORT=3000 SERVER_COMPRESSION_STATIC=true
EOF

# --- H2O --------------------------------------------------------------------
# Built from the distribution package. If it will not install, the contestant is
# EXCLUDED AND SAID SO in the report — never silently dropped, because a missing
# contestant looks identical to a contestant that lost.
cat > h2o.conf <<'EOF'
listen: 3000
hosts:
  "default":
    paths:
      "/":
        file.dir: /srv
file.send-compressed: ON
access-log: /dev/null
error-log: /dev/null
num-threads: 4   # 0 is not 'auto' to h2o — it refuses to start
EOF
cat > Dockerfile.h2o <<'EOF'
FROM debian:12
RUN apt-get update -qq && apt-get install -y -qq h2o && rm -rf /var/lib/apt/lists/*
COPY h2o.conf /etc/h2o.conf
COPY site /srv
ENTRYPOINT ["h2o", "-c", "/etc/h2o.conf"]
EOF

# --- OpenLiteSpeed ----------------------------------------------------------
cat > Dockerfile.ols <<'EOF'
FROM litespeedtech/openlitespeed:latest
# The image's default vhost serves from Example/html, not vhosts/localhost.
# Putting files in the wrong root does not fail loudly — it serves the stock
# 404 page for every request, at a perfectly respectable speed.
COPY site /usr/local/lsws/Example/html
# Its Example vhost ships `context /docs/` pointing at OpenLiteSpeed's OWN
# manual, which shadows any /docs/ path in the site being served. Seven of this
# site's pages live under /docs/, and every one of them came back as the stock
# 404 while the other 1,111 were perfect — a partial shadow, which is harder to
# spot than a total failure because the server looks like it is working.
RUN sed -i '/^context \/docs\/{/,/^}/d' /usr/local/lsws/conf/vhosts/Example/vhconf.conf
EOF

echo "==> building images"
: > /root/bench/excluded.txt
for c in orisha-cold orisha-warm nginx h2o; do
	if docker build -q -f "Dockerfile.$c" -t "bench-$c" . >/dev/null 2>"/tmp/build-$c.log"; then
		echo "    ok      $c"
	else
		echo "    EXCLUDED $c — see /tmp/build-$c.log"
		echo "$c: image build failed — $(tail -1 /tmp/build-$c.log | head -c 200)" >> /root/bench/excluded.txt
	fi
done

echo "==> images built"
docker images --format '{{.Repository}} {{.Size}}' | grep '^bench-' || true
