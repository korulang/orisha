#!/usr/bin/env python3
"""
HttpArena-shaped access logs for Orisha compile-time PGO (`orisha.profile`).

The compiler reads `orisha.profile` from the working directory at compile time
and reorders:
  - static route bodies (layout in the binary)
  - `orisha:router` pattern branches (if-chain order)

Train and held-out test are drawn from the same distribution but different
samples — same discipline as benchmarks/twobox/workload.py.

  ./workload.py --profile baseline --train profiles/generated/baseline.profile
  ./workload.py --profile board-mix --train profiles/generated/board-mix.profile
"""
from __future__ import annotations

import argparse
import random
import sys
from pathlib import Path

# (path_without_query, weight) — mirrors gcannon template mixes where possible.
MIXES: dict[str, list[tuple[str, float]]] = {
    "baseline": [
        ("/baseline11", 1.0),
        ("/baseline11", 1.0),  # GET + POST share path in logs
        ("/baseline11", 1.0),
    ],
    "limited-conn": [
        ("/baseline11", 1.0),
    ],
    "pipelined": [
        ("/pipeline", 1.0),
    ],
    "json-comp": [
        ("/json/25", 1.0),
        ("/json/40", 1.0),
        ("/json/50", 1.0),
    ],
    "json-tls": [
        ("/json/25", 1.0),
        ("/json/40", 1.0),
        ("/json/50", 1.0),
    ],
    "latency": [
        ("/baseline11", 1.0),
    ],
    "board-mix": [
        ("/baseline11", 3.0),
        ("/pipeline", 0.5),
        ("/json/25", 1.0),
        ("/json/40", 1.0),
        ("/json/50", 1.0),
    ],
}


def log_line(path: str) -> str:
    return (
        f'127.0.0.1 - - [01/Jan/2026:00:00:00 +0000] '
        f'"GET {path} HTTP/1.1" 200 0 "-" "-"\n'
    )


def draw(paths: list[str], weights: list[float], n: int, seed: int) -> list[str]:
    r = random.Random(seed)
    return r.choices(paths, weights=weights, k=n)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--profile",
        choices=sorted(MIXES.keys()),
        required=True,
        help="HttpArena profile shape to emulate",
    )
    ap.add_argument("--train", type=Path, help="orisha.profile for compile")
    ap.add_argument("--train-n", type=int, default=100_000)
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument(
        "--list",
        action="store_true",
        help="List available profile mixes and exit",
    )
    args = ap.parse_args()

    if args.list:
        for name, mix in MIXES.items():
            print(f"{name}: {', '.join(p for p, _ in dict.fromkeys(mix))}")
        return

    if args.train is None:
        ap.error("--train is required unless --list")

    mix = MIXES[args.profile]
    paths = [p for p, _ in mix]
    weights = [w for _, w in mix]
    train = draw(paths, weights, args.train_n, args.seed + 1)

    args.train.parent.mkdir(parents=True, exist_ok=True)
    with args.train.open("w") as fh:
        for p in train:
            fh.write(log_line(p))

    print(
        f"wrote {args.train}  profile={args.profile}  n={args.train_n}  "
        f"paths={len(set(paths))}  seed={args.seed}",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
