#!/usr/bin/env bash
# Build the vendored SQLite amalgamation for the orisha contestant.
# This is the SAME sqlite3.c that rusqlite's `bundled` feature compiles
# (libsqlite3-sys vendors it verbatim), built with its exact flag set, so
# the benchmark compares driver paths — not three different sqlite builds.
#
# Source: https://sqlite.org/2026/sqlite-amalgamation-*.zip (3.53.2), or copy
# sqlite3.c/sqlite3.h from a cargo registry libsqlite3-sys checkout.
set -euo pipefail
SRC="${1:-$HOME/.cargo/registry/src}"
SQLITE_C=$(find "$SRC" -name sqlite3.c -path "*libsqlite3*/sqlite3/*" 2>/dev/null | head -1)
[ -n "$SQLITE_C" ] || { echo "no vendored sqlite3.c found; pass the dir containing it"; exit 1; }
cc -O3 -c "$SQLITE_C" -o "$(dirname "$0")/dynamic/orisha/sqlite3_amalg.o" \
  -DSQLITE_CORE -DSQLITE_DEFAULT_FOREIGN_KEYS=1 -DSQLITE_ENABLE_API_ARMOR \
  -DSQLITE_ENABLE_COLUMN_METADATA -DSQLITE_ENABLE_DBSTAT_VTAB -DSQLITE_ENABLE_FTS3 \
  -DSQLITE_ENABLE_FTS3_PARENTHESIS -DSQLITE_ENABLE_FTS5 -DSQLITE_ENABLE_JSON1 \
  -DSQLITE_ENABLE_LOAD_EXTENSION=1 -DSQLITE_ENABLE_MEMORY_MANAGEMENT -DSQLITE_ENABLE_RTREE \
  -DSQLITE_ENABLE_STAT4 -DSQLITE_SOUNDEX -DSQLITE_THREADSAFE=1 -DSQLITE_USE_URI \
  -DHAVE_USLEEP=1 -DHAVE_ISNAN
echo "built dynamic/orisha/sqlite3_amalg.o from $SQLITE_C"
