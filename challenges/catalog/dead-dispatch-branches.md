---
cost: dead-dispatch-branches
organ: framework
status: closed
closed-by: lib/httparena.kz rewrite → pure-Koru lib/httparena.k, 2026-10-14 session
---

# dead dispatch branches

**Cost:** the old Zig handler carried a hand-rolled path dispatcher
(`std.mem.eql` chains) *inside* the app, duplicating the router transform's
job — plus unreachable arms and response paths that never fired.

**Fix:** deleted `lib/httparena.kz` entirely (500 lines of Zig); all handler
logic now lives in `lib/httparena.k` flows compiled by the real router —
which itself emits `body: "ok"` as a wire voucher with `wire_date_hole`,
no app code needed.

**Evidence:** local A/B, linux pump, wrk -t6 -c512 -d12s: baseline
313.9k → 399.4k req/s (+27%) after the rewrite. Some of that delta is
dispatch removal, some is response-path simplification — the catalog does
not split them further.
