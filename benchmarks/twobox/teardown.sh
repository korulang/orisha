#!/usr/bin/env bash
# Destroy the pair. Cheap to run, and cheaper than forgetting.
set -euo pipefail
doctl compute droplet delete --tag-name orisha-twobox --force 2>/dev/null || true
sleep 3
left="$(doctl compute droplet list --tag-name orisha-twobox --format Name --no-header | wc -l | tr -d ' ')"
echo "droplets remaining: $left"
rm -f "$(cd "$(dirname "$0")" && pwd)/.hosts"
