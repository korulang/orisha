# Fanout cost is coordination shape, not the send call

**Belief formed (2026-10-11):** in a broadcast pump, the thing that
determines whether fanout scales is *who performs the write and what the
bytes cost per recipient* — not how fast any individual send is. Three
successive architectures were measured on the same Campfire load
(4 posters, 1 stream, fresh DB, same box):

- **Producer-push** (foreign threads `writev` into arbitrary sockets):
  fine at N=100 (~1,383 delivered msg/s), collapses at N=500 (~174).
  The send lock is held across the syscall, so 500 non-writable sockets
  turn into a mutex convoy — `__ulock_wait2` dominated the profile.
- **Owner-pull with per-conn byte copies** (`pending` as an ArrayList of
  bytes): recovers to ~690 at N=500 but still pays payload-size ×
  subscribers memcpy per broadcast (~4.7 MB at 500 × 9.4 KB) plus
  ArrayList realloc churn — `memmove`/`mmap`/`munmap` were the profile.
- **Owner-pull with shared refcounted frames + lock-free SPSC queue**
  (`Frame` = atomic refcount + bytes; `wsq` = Vyukov segment queue,
  `conn_states_mu` gates lifetime, `armed` atomic gates wakeups):
  ~719 at N=500, ~2,524 at N=100 — ahead of the Rust/axum comparator
  (~2,241) — with `ulock_wait2` down ~40× and zero `munmap` on the hot
  path.

**The rule that generalizes:** a fanout producer should do O(1) work per
subscriber — an incref and a pointer push — and the owner reactor should
be the only thread that ever touches a socket. Every alternative puts
the copy, the lock, or the syscall on the wrong side of that line.
`delivered == posted, drain ≈ 0` is the signature that fanout has
stopped being the limiter — after that, remaining gaps live in the
request path, not the pump.

**Ordering is cheaper than it looks:** the drainer shards fds
(`fd % K`), so each conn has exactly one broadcast producer — the
"lock-free MPSC" degenerates to SPSC, and a single atomic-tail swap is
all the synchronization a push needs.

Open: at N=500 the residual gap to Rust (~85%) is per-frame CPU
efficiency inside the owner drain and request-path sqlite work, not
fanout shape. If that ever matters, the next levers are syscall batch
shape and request-path retention, not more queue machinery.
