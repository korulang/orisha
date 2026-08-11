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
if [ "$EXISTING" != "0" ]; then
	echo "$EXISTING droplet(s) already tagged $TAG. Run ./teardown.sh first, or REUSE=1 to use them." >&2
	[ "${REUSE:-0}" = "1" ] || exit 1
	echo "==> reusing the existing pair"
else
echo "==> creating 2x $SIZE in $REGION (vpc ${VPC_ID:-default})"
for name in orisha-bench-server orisha-bench-load; do
	doctl compute droplet create "$name" \
		--region "$REGION" --size "$SIZE" --image "$IMAGE" \
		--ssh-keys "$KEY_ID" --tag-name "$TAG" \
		${VPC_ID:+--vpc-uuid "$VPC_ID"} \
		--wait --format ID,Name,PublicIPv4 --no-header
done
fi

# Public IP to reach them from here; private IP for the load itself.
read_ip() { doctl compute droplet list --tag-name "$TAG" --format Name,PublicIPv4,PrivateIPv4 --no-header | awk -v n="$1" '$1==n {print $2, $3}'; }

read -r SERVER_PUB SERVER_PRIV <<<"$(read_ip orisha-bench-server)"
read -r LOAD_PUB   LOAD_PRIV   <<<"$(read_ip orisha-bench-load)"

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
