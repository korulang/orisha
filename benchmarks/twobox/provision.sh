#!/usr/bin/env bash
# Bring up the two machines: one serves, one loads. Same region, same VPC, so
# the traffic between them never touches the public internet.
#
# Dedicated CPU (c-4) rather than shared, because a shared-tenancy machine loses
# cycles to its neighbours and reports nothing about it. That shows up as CPU
# steal, which we sample during every run — but the cheaper fix is to not rent a
# machine that has neighbours in the first place.
set -euo pipefail

REGION="${REGION:-ams3}"
SIZE="${SIZE:-c-4}"
IMAGE="${IMAGE:-debian-13-x64}"
KEY_NAME="${KEY_NAME:-koru-bench}"
TAG="orisha-twobox"
# Self-destruct backstop: each droplet deletes ITSELF via the DO API at
# boot+TTL (systemd timespan). teardown.sh is still the normal end — this only
# exists because a leaked pair once ran 55h when teardown never ran, and a
# powered-off droplet still bills. TTL bounds the worst case to TTL × rate.
# REUSE=1 note: a reused pair keeps its original clock — it dies at ITS
# boot+TTL regardless of the second run. To extend, ssh in and
# `systemctl stop twobox-self-destruct.timer`.
TTL="${TTL:-6h}"

here() { cd "$(dirname "$0")" && pwd; }
HERE="$(here)"

KEY_ID="$(doctl compute ssh-key list --format ID,Name --no-header | awk -v n="$KEY_NAME" '$2==n {print $1}')"
if [ -z "$KEY_ID" ]; then
	echo "No SSH key named '$KEY_NAME' on the account. Add one first." >&2
	exit 1
fi

VPC_ID="$(doctl vpcs list --format ID,Region,Default --no-header | awk -v r="$REGION" '$2==r {print $1; exit}')"

# Refuse to add a second pair on top of a first. A stale pair does not announce
# itself: the tag lookup happily returns four machines, the IPs come out of a
# race, and the bill quietly doubles. Measured 2026-08-11, by doing it.
EXISTING="$(doctl compute droplet list --tag-name "$TAG" --format Name --no-header | wc -l | tr -d ' ')"
REUSED=0
if [ "$EXISTING" != "0" ]; then
	echo "$EXISTING droplet(s) already tagged $TAG. Run ./teardown.sh first, or REUSE=1 to use them." >&2
	[ "${REUSE:-0}" = "1" ] || exit 1
	REUSED=1
	echo "==> reusing the existing pair (dies at ITS boot+TTL — stop twobox-self-destruct.timer to extend)"
else
# Token for the droplet's self-destruct. Prefer a scoped PAT (custom scopes:
# droplet:delete + its required reads — console-only to create, DO has no
# token-minting endpoint) via DO_SELF_DESTRUCT_TOKEN or
# ~/.config/digitalocean/self-destruct-token — the same convention
# koru-benchmarks/scripts/bench-on-droplet.sh uses, so one scoped PAT covers
# both. Else the doctl PAT. Even the full token's blast radius is bounded: the
# timer DELETEs only the droplet's own metadata ID, and it dies with the box.
SD_TOKEN="${DO_SELF_DESTRUCT_TOKEN:-}"
if [ -z "$SD_TOKEN" ] && [ -f "$HOME/.config/digitalocean/self-destruct-token" ]; then
	SD_TOKEN="$(tr -d '[:space:]' < "$HOME/.config/digitalocean/self-destruct-token")"
fi
if [ -z "$SD_TOKEN" ]; then
	SD_TOKEN="$(doctl auth token)"
	echo "!! no scoped token (DO_SELF_DESTRUCT_TOKEN / ~/.config/digitalocean/self-destruct-token)" >&2
	echo "!! — embedding your full-access doctl token on the droplets" >&2
fi

USERDATA="$(mktemp "${TMPDIR:-/tmp}/twobox-userdata.XXXXXX")"
trap 'rm -f "$USERDATA"' EXIT
# NOTE: \$ inside the script body must survive this heredoc unexpanded.
# Keep this file pure ASCII — cloud-init's YAML parse refused an em-dash
# (#x0080) and silently armed nothing. Measured 2026-10-08.
cat > "$USERDATA" <<EOF
#cloud-config
write_files:
  - path: /usr/local/bin/twobox-self-destruct
    permissions: "0700"
    content: |
      #!/bin/sh
      ID="\$(curl -sf --retry 5 http://169.254.169.254/metadata/v1/id)" || exit 1
      for i in 1 2 3 4 5; do
        curl -sf -X DELETE -H "Authorization: Bearer $SD_TOKEN" \\
          "https://api.digitalocean.com/v2/droplets/\$ID" && exit 0
        sleep 10
      done
      exit 1
  - path: /etc/systemd/system/twobox-self-destruct.service
    content: |
      [Unit]
      Description=Destroy this bench droplet - billing backstop
      [Service]
      Type=oneshot
      ExecStart=/usr/local/bin/twobox-self-destruct
  - path: /etc/systemd/system/twobox-self-destruct.timer
    content: |
      [Unit]
      Description=Destroy this droplet $TTL after boot
      [Timer]
      OnBootSec=$TTL
      Unit=twobox-self-destruct.service
      [Install]
      WantedBy=timers.target
runcmd:
  - systemctl daemon-reload
  - systemctl enable --now twobox-self-destruct.timer
EOF

echo "==> creating 2x $SIZE in $REGION (vpc ${VPC_ID:-default}, self-destruct at boot+$TTL)"
for name in orisha-bench-server orisha-bench-load; do
	doctl compute droplet create "$name" \
		--region "$REGION" --size "$SIZE" --image "$IMAGE" \
		--ssh-keys "$KEY_ID" --tag-name "$TAG" \
		--user-data-file "$USERDATA" \
		${VPC_ID:+--vpc-uuid "$VPC_ID"} \
		--wait --format ID,Name,PublicIPv4 --no-header
done
fi

# Public IP to reach them from here; private IP for the load itself.
# --wait means active, not networked: IPs can still be empty for a minute —
# poll, or `read` gets an empty heredoc and set -e buries the run.
read_ip() { doctl compute droplet list --tag-name "$TAG" --format Name,PublicIPv4,PrivateIPv4 --no-header | awk -v n="$1" '$1==n {print $2, $3}'; }
wait_ip() { for _ in $(seq 1 24); do out="$(read_ip "$1")"; [ -n "$(echo "$out" | awk '{print $1}')" ] && [ -n "$(echo "$out" | awk '{print $2}')" ] && { echo "$out"; return 0; }; sleep 5; done; echo "no IPs for $1 after 2min" >&2; return 1; }

read -r SERVER_PUB SERVER_PRIV <<<"$(wait_ip orisha-bench-server)"
read -r LOAD_PUB   LOAD_PRIV   <<<"$(wait_ip orisha-bench-load)"

# wait_ip's return code dies inside <<<"$(...)" — check the values it was
# protecting. A fresh pair with no IPs still bills, so don't leave it up.
if [ -z "${SERVER_PUB:-}" ] || [ -z "${SERVER_PRIV:-}" ] || [ -z "${LOAD_PUB:-}" ] || [ -z "${LOAD_PRIV:-}" ]; then
	echo "!! no IPs assigned — refusing to write a broken .hosts" >&2
	[ "$REUSED" = 1 ] || "$HERE/teardown.sh" || true
	exit 1
fi

cat > "$HERE/.hosts" <<EOF
SERVER_PUB=$SERVER_PUB
SERVER_PRIV=$SERVER_PRIV
LOAD_PUB=$LOAD_PUB
LOAD_PRIV=$LOAD_PRIV
REGION=$REGION
SIZE=$SIZE
EOF

echo "==> server $SERVER_PUB (private $SERVER_PRIV)"
echo "==> load   $LOAD_PUB (private $LOAD_PRIV)"

SSH_OPTS="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i ${SSH_KEY:-$HOME/.ssh/koru_bench}"
echo "==> waiting for ssh"
for ip in "$SERVER_PUB" "$LOAD_PUB"; do
	for _ in $(seq 1 60); do
		if ssh $SSH_OPTS "root@$ip" true 2>/dev/null; then echo "    $ip up"; break; fi
		sleep 5
	done
done

# The backstop only counts if it armed — cloud-init can silently apply none of
# the userdata (measured: one em-dash killed the YAML parse and armed nothing).
# list-timers shows NEXT, so this proves the countdown, not just the file.
# But ssh wins the boot race — runcmd hasn't run yet when first login lands,
# so wait for cloud-init to finish before judging. Measured 2026-10-08: both
# fresh pairs reported the load box unarmed until cloud-init status --wait.
echo "==> verifying the self-destruct timer is armed"
armed=1
for ip in "$SERVER_PUB" "$LOAD_PUB"; do
	ssh $SSH_OPTS "root@$ip" 'timeout 180 cloud-init status --wait >/dev/null 2>&1 || true'
	next="$(ssh $SSH_OPTS "root@$ip" 'systemctl list-timers twobox-self-destruct.timer --no-legend 2>/dev/null' | awk '{print $1, $2}')"
	if [ -n "$next" ]; then
		echo "    $ip armed — fires $next"
	else
		echo "    $ip: NO SELF-DESTRUCT TIMER — droplet has no billing backstop" >&2
		armed=0
	fi
done
if [ "$armed" != 1 ]; then
	if [ "$REUSED" = 1 ]; then
		echo "!! reused pair predates the backstop — it dies only via teardown.sh" >&2
	else
		echo "!! userdata did not apply — destroying the pair rather than leaking it" >&2
		"$HERE/teardown.sh" || true
		exit 1
	fi
fi
