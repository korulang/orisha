#!/usr/bin/env bash
# Seed the shared SQLite users table the dynamic benchmark legs read.
# Servers open ../bench.db relative to benchmarks/dynamic/<contestant>.
set -euo pipefail
DB="$(dirname "$0")/dynamic/bench.db"
sqlite3 "$DB" "DROP TABLE IF EXISTS users;
CREATE TABLE users(id INTEGER PRIMARY KEY, name TEXT NOT NULL);
WITH RECURSIVE g(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM g WHERE i<10000)
  INSERT INTO users(id,name) SELECT i, 'User '||i FROM g;"
echo "seeded $DB ($(sqlite3 "$DB" 'SELECT COUNT(*) FROM users;') rows)"
