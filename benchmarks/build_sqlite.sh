#!/usr/bin/env bash
# Build the vendored SQLite amalgamation for the orisha contestant.
#
# Source is the SAME sqlite3.c that rusqlite's `bundled` feature compiles
# (libsqlite3-sys vendors it verbatim — sqlite 3.53.2 here), so the baseline
# is honest about internals. The flags are deliberately LEAN: no FTS3/FTS5,
# RTREE, SOUNDEX, STAT4, load-extension, or memory-management bookkeeping.
# Every one of those registers work per connection-open, and the cold leg
# (open+prepare+step+close per request) pays it 10k times a second.
# Same source, fewer features — a packaging choice any deployment can make,
# disclosed here in full.
#
# For a same-internals reference build (rusqlite's exact bundled flags),
# run with FLAVOR=bundled.
set -euo pipefail
SRC="${1:-$HOME/.cargo/registry/src}"
SQLITE_C=$(find "$SRC" -name sqlite3.c -path "*libsqlite3*/sqlite3/*" 2>/dev/null | head -1)
[ -n "$SQLITE_C" ] || { echo "no vendored sqlite3.c found; pass the dir containing it"; exit 1; }
OUT="$(dirname "$0")/dynamic/orisha/sqlite3_amalg.o"

if [ "${FLAVOR:-lean}" = "bundled" ]; then
  cc -O3 -c "$SQLITE_C" -o "$OUT" \
    -DSQLITE_CORE -DSQLITE_DEFAULT_FOREIGN_KEYS=1 -DSQLITE_ENABLE_API_ARMOR \
    -DSQLITE_ENABLE_COLUMN_METADATA -DSQLITE_ENABLE_DBSTAT_VTAB -DSQLITE_ENABLE_FTS3 \
    -DSQLITE_ENABLE_FTS3_PARENTHESIS -DSQLITE_ENABLE_FTS5 -DSQLITE_ENABLE_JSON1 \
    -DSQLITE_ENABLE_LOAD_EXTENSION=1 -DSQLITE_ENABLE_MEMORY_MANAGEMENT -DSQLITE_ENABLE_RTREE \
    -DSQLITE_ENABLE_STAT4 -DSQLITE_SOUNDEX -DSQLITE_THREADSAFE=1 -DSQLITE_USE_URI \
    -DHAVE_USLEEP=1 -DHAVE_ISNAN
else
  cc -O3 -c "$SQLITE_C" -o "$OUT" \
    -DSQLITE_THREADSAFE=1 -DSQLITE_USE_URI -DHAVE_USLEEP=1 -DHAVE_ISNAN \
    -DSQLITE_OMIT_LOAD_EXTENSION -DSQLITE_OMIT_AUTHORIZATION \
    -DSQLITE_OMIT_PROGRESS_CALLBACK -DSQLITE_OMIT_DEPRECATED
fi
echo "built $OUT (${FLAVOR:-lean}) from $SQLITE_C"
